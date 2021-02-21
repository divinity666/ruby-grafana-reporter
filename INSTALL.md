[![MIT License](https://img.shields.io/github/license/divinity666/ruby-grafana-reporter.svg?style=flat-square)](https://github.com/divinity666/ruby-grafana-reporter/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/divinity666/ruby-grafana-reporter.svg?branch=master)](https://travis-ci.org/github/divinity666/ruby-grafana-reporter?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/divinity666/ruby-grafana-reporter/badge.svg?branch=master)](https://coveralls.io/github/divinity666/ruby-grafana-reporter?branch=master)

# Ruby Grafana Reporter
Reporting Service for Grafana

## Table of Contents

* [Installation details](#installation-details)
  * [Initial Configuration](#initial-configuration)
  * [Option 1) "Baremetal" Ruby](#baremetal-ruby)
  * [Option 2) As a GEM](#as-a-gem)
  * [Option 3) Docker](#docker)

## Installation details

Please note that this is the detailed installation documentation. A quick start
guide can be found in the [readme](README.md).

There exist several ways of installing the reporter. All of them have in
common, that they require a working ruby environment. Check with the following
commands, that the tools are setup and run properly:

    ruby -v
    gem -v

### Initial Configuration

#### Configuration file

Please note that you can skip this step, if you first install the reporter, as it
also provides a configuration wizard which can be called via command line:

    ruby-grafana-reporter -w

Otherwise you may want to follow these steps.

Create a first configuration file, named `grafana-reporter.config` with the following
content:

    grafana-reporter:
      templates-folder: templates
      reports-folder: reports

    grafana:
      default:
        host: <<url to your grafana host, e.g. https://localhost:3000>>
        api_key: <<api key to be used by the reporter>>

    default-document-attributes:
      imagesdir: .

#### "Hello World" asciidoctor template

Create a first asciidoctor template file in your `templates-folder`, e.g.
`myfirsttemplate.adoc` with the following content:

    = First Ruby Grafana Reporter Example

    include::grafana_help[]

    include::grafana_environment[]

Now you're ready to go! Let's check it out!

### "Baremetal" Ruby

To install on a plain ruby installation, make sure that the `ruby` command is
accessible from your command line and then follow these steps:

Download the ruby grafana reporter to a folder of your choice.

Install asciidoctor

    gem install asciidoctor asciidoctor-pdf zip

or simply use

    bundle install

To check if all dependencies are setup properly, run the following command
in that folder:

    ruby bin/ruby-grafana-reporter -h

Check that your configured grafana instance can be accessed properly:

    ruby bin/ruby-grafana-reporter --test default

Now you may want to check the conversion of your Hello World example:

    ruby bin/ruby-grafana-reporter --template myfirsttemplate --output myfirstrender.pdf

You should now find a PDF document named `myfirstrender.pdf` which includes a detailed
help page on how to use the ruby grafana reporter functions in asciidoctor, as well
as a list of all environment variables that can be accessed.

If this has been working properly as well, you might want to run the reporter
as a webservice. Nothing easier than that. Just call:

    ruby bin/ruby-grafana-reporter

Test your configuration by requesting the following URL in a browser of your
choice:

    http://<<your-server-url>>:8815/render?var-template=myfirsttemplate

If this now also serves you the PDF document after a few seconds (remember to
reload the page), you are done with the reporter service and might want to go
to step into the integration with grafana.

### As a GEM

Installation as a gem is a simple way, if you don't want to mess with the
efforts of a barebone installation.

To install as a gem, simply run:

    gem install ruby-grafana-reporter

To see if it works properly, you may run the application:

    ruby-grafana-reporter

To check if your configured grafana instance can be accessed properly:

    ruby-grafana-reporter --test default

Now you may want to check the conversion of your Hello World example:

    ruby-grafana-reporter --template myfirsttemplate --output myfirstrender.pdf

You should now find a PDF document named `myfirstrender.pdf` which includes a detailed
help page on how to use the ruby grafana reporter functions in asciidoctor, as well
as a list of all environment variables that can be accessed.

If this has been working properly as well, you might want to run the reporter
as a webservice. Nothing easier than that. Just call:

    ruby-grafana-reporter

Test your configuration by requesting the following URL in a browser of your
choice:

    http://<<your-server-url>>:8815/render?var-template=myfirsttemplate

If this now also serves you the PDF document after a few seconds (remember to
reload the page), you are done with the reporter service and might want to go
to step into the integration with grafana.

### Docker

One of the key features of the reporter is, that it can work seemlessly with
the official `asciidoctor` docker container without further dependencies.

Assuming you have a `docker-compose` setup running, you may want to add the
following to your services secion in your `docker-compose.yml`:

    asciidoctor:
      image: asciidoctor/docker-asciidoctor
      container_name: asciidoctor
      hostname: asciidoctor
      volumes:
        - /<<an-empty-local-path>>:/documents
      restart: unless-stopped

After running this container, you have to copy the reporter files. Download the
ruby grafana reporter to the folder `<<an-empty-local-path>>`. I tend to use
the single file application there.

To test the setup, you'll have to first step inside the container, e.g. by
calling `docker exec` with the appropriate parameters. Then you can simply
run

    ruby bin/ruby-grafana-reporter -h

Check that your configured grafana instance can be accessed properly:

    ruby bin/ruby-grafana-reporter --test default

Now you may want to check the conversion of your Hello World example:

    ruby bin/ruby-grafana-reporter --template myfirsttemplate --output myfirstrender.pdf

You should now find a PDF document named `myfirstrender.pdf` which includes a detailed
help page on how to use the ruby grafana reporter functions in asciidoctor, as well
as a list of all environment variables that can be accessed.

If this has been working properly as well, you might want to run the reporter
as a webservice always when starting the container. To do so, use the following
`docker-compose` configuration. Watch out for the added lines!

    asciidoctor:
      image: asciidoctor/docker-asciidoctor
      container_name: asciidoctor
      hostname: asciidoctor
      volumes:
        - /<<an-empty-local-path>>:/documents
      command:
        sh /documents/startup.sh
      restart: unless-stopped

Additionally you need to create a `startup.sh` file in the folder
`<<an-empty-local-path>>` with the following content:

    cd /documents
    ruby bin/ruby-grafana-reporter

After restarting the container, the service should be running.

Test your configuration by requesting the following URL in a browser of your
choice:

    http://<<your-server-url>>:8815/render?var-template=myfirsttemplate

If this now also serves you the PDF document after a few seconds (remember to
reload the page), you are done with the reporter service and might want to go
to step into the integration with grafana.
