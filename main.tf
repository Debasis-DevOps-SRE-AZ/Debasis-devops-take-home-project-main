module "base_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"
  namespace = "ll"
}

# Variables (unchanged)

# VPC Resource (unchanged)

# Create Subnets
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 2, 1)  # Public subnet
  availability_zone = data.aws_availability_zones.available.names[0]

  # Public subnet needs access to internet
  map_public_ip_on_launch = true

  # Use label module for consistent naming based on VPC name
  tags = module.label_vpc.tags({
    Name = format("%s-public", module.label.resource_name(aws_vpc.main.name))
  })
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 2, 2)  # Private subnet
  availability_zone = data.aws_availability_zones.available.names[0]

  # Private subnet doesn't need internet access
  map_public_ip_on_launch = false

  # Use label module for consistent naming based on VPC name
  tags = module.label_vpc.tags({
    Name = format("%s-private", module.label.resource_name(aws_vpc.main.name))
  })
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Helper function to calculate subnet CIDRs (from hashicorp/subnets/cidr)
function "cidrsubnet" {
  cidr     = var.vpc_cidr
  num_nets = var.num_nets
  subnet_id = var.subnet_id

  cidr_prefixlen = slice(split("/", cidr)[0], 0, length(split("/", cidr)[0]) - 1)
  cidr_suffix    = split("/", cidr)[1]

  if cidr_prefixlen < 16 || cidr_prefixlen > 28 {
    error("Invalid CIDR prefix length")
  }

  if num_nets < 2 || num_nets > (1 << (cidr_prefixlen - cidr_suffix)) {
    error("Invalid number of subnets")
  }

  if subnet_id < 1 || subnet_id > num_nets {
    error("Invalid subnet ID")
  }

  base_cidr = format("%s/%d", cidr_prefixlen, cidr_suffix + log2(num_nets))
  subnet_cidr = format("%s.%d.%d.0/24",
      slice(split(".", base_cidr)[0], 0, length(split(".", base_cidr)[0]) - 1),
      floor(int(split(".", base_cidr)[length(split(".", base_cidr)[0]) - 1]) + ((subnet_id - 1) / 256)),
      ((subnet_id - 1) % 256))

  return subnet_cidr
}
