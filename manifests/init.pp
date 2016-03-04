# a class that is mean to make us a nice graph
class exampleawsgraph {
  $subnets = ['licenseservice-avza','licenseservice-avzb','licenseservice-avzc']
  $number_of_app_servers = 6
  $region = 'us-west-2'
  $ami = 'ami-d440a6e7'
  $instances = [
    'app-1',
    'app-2',
    'app-3',
    'app-4',
    'app-5',
  ]

  Ec2_instance {
    ensure        => 'running',
    image_id      => $ami,
    security_groups => ['licenseservice-agents'],
    instance_type => 't1.micro',
    region        => $region,
  }

  awsenv::vpc { 'licenseservice':
    region      => $region,
    department  => 'webapp',
    vpc_mask    => '10.90.0.0',
    zone_a_mask => '10.90.80.0',
    zone_b_mask => '10.90.70.0',
    zone_c_mask => '10.90.60.0',
    created_by  => 'chrisbarker',
  }


  $web_nodes = range(1, $number_of_app_servers).map |$node| {
    $subnet = $node % $subnets.count
    [$node, $subnets[$subnet]]
  }

  hash(flatten($web_nodes)).each |$node_num, $subnet| {
    $instance_name = "app-${node_num}"
    $avz = $subnet ? {
      /.*a$/  => "${region}a",
      /.*b$/  => "${region}b",
      /.*c$/  => "${region}c",
      default => undef
    }
    ec2_instance { $instance_name:
      subnet => $subnet,
      availability_zone => $avz,
      before => Elb_loadbalancer['licenseservice-lb'],
      require => [
        Ec2_vpc_subnet[$subnet],
        Ec2_securitygroup['licenseservice-agents']
      ]
    }
  }



  elb_loadbalancer { 'licenseservice-lb':
    ensure               => present,
    region               => $region,
    availability_zones   => ["${region}a","${region}b","${region}c"],
    instances            => $instances,
    security_groups      => ['licenseservice-agents'],
    listeners            => [{
      protocol           => 'tcp',
      load_balancer_port => 80,
      instance_protocol  => 'tcp',
      instance_port      => 80,
    }],
  }



}
