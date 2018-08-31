# Velum

| master | Code Climate |
|--------|--------------|
| [![Build Status](https://travis-ci.org/kubic-project/velum.svg?branch=master)](https://travis-ci.org/kubic-project/velum) | [![Code Climate](https://codeclimate.com/github/kubic-project/velum/badges/gpa.svg)](https://codeclimate.com/github/kubic-project/velum) [![Test Coverage](https://codeclimate.com/github/kubic-project/velum/badges/coverage.svg)](https://codeclimate.com/github/kubic-project/velum/coverage) |

Velum is a dashboard that manages your SUSE CaaS Platform cluster. With Velum, you will
be able to:

- Bootstrap a Kubernetes cluster with a simple click.
- Manage your Kubernetes cluster: adding and removing nodes from your cluster,
  monitoring faulty nodes, etc.
- Setup an update policy that suits your needs. SUSE CaaS Platform already provides a
  transparent and sensible procedure for updates that guarantees no downtime,
  but with Velum you will be able to further tune this.

The architecture of CaaS Platform uses [Salt](https://saltstack.com/) quite heavily,
and worker nodes are supposed to run as
[Salt minions](https://docs.saltstack.com/en/latest/ref/cli/salt-minion.html). These
Salt minions should then register to Velum, which acts as a Salt master. As an
administrator, when setting up the cluster, you will see nodes popping up, and
then you will be able to provision all the nodes from your cluster with Kubernetes
in a single click.

Once you have bootstrapped your cluster, you will be presented with a web
application that allows you to manage your cluster, define your update policy,
and much more.

## Configuration

Given that you have already running the salt master instance, set the following environment
variables and start the server:

- `VELUM_SALT_HOST`: IP of the Salt API server.
- `VELUM_SALT_PORT`: Port of the Salt API server.
- `VELUM_SALT_USER`: The user allowed to access the Salt API.

Note that the development environment already sets all these values for you.

## Development

You can start a Velum development environment by following the instructions in [caasp-devenv](https://github.com/kubic-project/automation#caasp-devenv).

## Testing

After you started a Velum development [environment](https://github.com/kubic-project/automation#caasp-devenv). Follow this steps:

1. ssh into the admin node (normally the IP is `10.17.1.0`)

2. run this docker command

    `docker exec -it $(docker ps -q -f 'name=velum-dashboard') entrypoint.sh bash -c "RAILS_ENV=test rspec spec"`

    This will execute the test battery inside the velum-dashboard container. To run a specific test file specify it like this:

    `docker exec -it $(docker ps -q -f 'name=velum-dashboard') entrypoint.sh bash -c "RAILS_ENV=test rspec spec/features/file_name_spec.rb"`

## Licensing

Velum is licensed under the Apache License, Version 2.0. See
[LICENSE](https://github.com/kubic-project/velum/blob/master/LICENSE) for the
full license text.
