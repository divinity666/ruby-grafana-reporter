[![MIT License](https://img.shields.io/github/license/divinity666/ruby-grafana-reporter.svg?style=flat-square)](https://github.com/divinity666/ruby-grafana-reporter/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/divinity666/ruby-grafana-reporter.svg?branch=master)](https://travis-ci.org/github/divinity666/ruby-grafana-reporter?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/divinity666/ruby-grafana-reporter/badge.svg?branch=master)](https://coveralls.io/github/divinity666/ruby-grafana-reporter?branch=master)

# Ruby Grafana Reporter
Reporting Service for Grafana

## Table of Contents

* [About the project](#about-the-project)
* [Getting started](#getting-started)
  * [Initial Configuration](#initial-configuration)
  * [Option 1) "Baremetal" Ruby](#baremetal-ruby)
  * [Option 2) As a GEM](#as-a-gem)
  * [Option 3) Docker](#docker)
  * [Grafana integration](#grafana-integration)
* [Webservice overview](#webservice-overview)
* [Features](#features)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [Licensing](#licensing)
* [Acknowledgements](#acknowledgements)
* [Donations](#donations)

## About the project

Did you ever want to create (professional) reports based on Grafana dashboards?
I did so in order to being able to automatically get monthly reports of my
home's energy usage. That's how it started.

The reporter provides reporting capabilities for Grafana. It is based on
(but not limited to) [asciidoctor](https://github.com/asciidoctor/asciidoctor)
report templates, which can dynamically integrate Grafana panels, queries,
images etc. to create dynamic PDF reports on the fly.

The report may also be returned in any other format that asciidoctor supports.

The reporter can run standalone or as a webservice. It is built to
integrate without further dependencies with the asciidoctor docker image.

The complete
[API documentation](https://rubydoc.info/gems/ruby-grafana-reporter) can be
found here.

## Getting started

There exist several ways of installing the reporter. All of them have in
common, that they require a working ruby environment. Check with the following
commands, that the tools are setup and run properly:

    ruby -v
    gem -v

### Initial Configuration

#### Configuration file

Create a first configuration file, named e.g. `myconfig` with the following
content:

    grafana-reporter:
      templates-folder: templates
      reports-folder: reports
    
    grafana:
      default:
        host: <<url to your grafana host, e.g. https://localhost:3000>>
        api_key: <<api key to be used by the reporter>>
        datasources: # mandatory, if the api_key has only viewer rights, optional otherwise
          "<<data source name in grafana>>": <<data source id in grafana>>
    
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

To install on a plain ruby installation, follow these steps:

Download the ruby grafana reporter to a folder of your choice.

Install asciidoctor

    gem install asciidoctor asciidoctor-pdf zip

or simply use

    bundle install

To check if all dependencies are setup properly, run the following command
in that folder:

    ruby bin/ruby-grafana-reporter.rb -h

Check that your configured grafana instance can be accessed properly:

    ruby bin/ruby-grafana-reporter.rb myconfig --test default

Now you may want to check the conversion of your Hello World example:

    ruby bin/ruby-grafana-reporter.rb myconfig --template myfirsttemplate.adoc --output myfirstrender.pdf

You should now find a PDF document named `myfirstrender.pdf` which includes a detailed
help page on how to use the ruby grafana reporter functions in asciidoctor, as well
as a list of all environment variables that can be accessed.

If this has been working properly as well, you might want to run the reporter
as a webservice. Nothing easier than that. Just call:

    ruby bin/ruby-grafana-reporter.rb myconfig

Test your configuration by requesting the following URL in a browser of your
choice:

    http://<<your-server-url>>:8815/render?var-template=myfirsttemplate.adoc

If this now also serves you the PDF document after a few seconds (remember to
reload the page), you are done with the reporter service and might want to go
to step into the integration with grafana.

### As a GEM

The gem installation might mainly be interesting, if you would like to use the
reporter as a library and include it in other application setups. Anyway you
can also you it identical as in the other examples. Let me show you how:

To install as a gem, simply run:

    gem install ruby-grafana-reporter

To see if it works properly, you may run the following code (easiest way might
be to check in `irb`, but you can also create an `.rb` file and run it with
the preceeding `ruby` command. Here's now the code:

    require 'ruby-grafana-reporter'
    GrafanaReporter::Application::Application.new.configure_and_run

To check if your configured grafana instance can be accessed properly:

    require 'ruby-grafana-reporter'
    GrafanaReporter::Application::Application.new.configure_and_run(["myconfig", "--test", "default"])

Now you may want to check the conversion of your Hello World example:

    require 'ruby-grafana-reporter'
    GrafanaReporter::Application::Application.new.configure_and_run(["myconfig", "--template", "myfirsttemplate.adoc", "--output", "myfirstrender.pdf"])

You should now find a PDF document named `myfirstrender.pdf` which includes a detailed
help page on how to use the ruby grafana reporter functions in asciidoctor, as well
as a list of all environment variables that can be accessed.

If this has been working properly as well, you might want to run the reporter
as a webservice. Nothing easier than that. Just call:

    require 'ruby-grafana-reporter'
    GrafanaReporter::Application::Application.new.configure_and_run(["myconfig"])

Test your configuration by requesting the following URL in a browser of your
choice:

    http://<<your-server-url>>:8815/render?var-template=myfirsttemplate.adoc

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

    ruby bin/ruby-grafana-reporter.rb -h

Check that your configured grafana instance can be accessed properly:

    ruby bin/ruby-grafana-reporter.rb myconfig --test default

Now you may want to check the conversion of your Hello World example:

    ruby bin/ruby-grafana-reporter.rb myconfig --template myfirsttemplate.adoc --output myfirstrender.pdf

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
    ruby bin/ruby-grafana-reporter.rb myconfig

After restarting the container, the service should be running.

Test your configuration by requesting the following URL in a browser of your
choice:

    http://<<your-server-url>>:8815/render?var-template=myfirsttemplate.adoc

If this now also serves you the PDF document after a few seconds (remember to
reload the page), you are done with the reporter service and might want to go
to step into the integration with grafana.

### Grafana integration

The key feature of the report is, that it can easily be integrated with grafana
(I've not even been talking about the features it is providing for that, but
you'll find them having a look in the example results above).

For accessing the reporter from grafana, you need to simply add a link to your
grafana dashboard:

* Open the dashboard configuration
* Select `Links`
* Select `Add`
* Fill out as following:
  * Type: `link`
  * Url: `http://<<your-server-url>>:8815/render?var-template=myfirsttemplate.adoc`
  * Title: `MyFirstReport`
  * Select `Time range`
  * Select `Variable values`
* Select `Add`

Now go back to your dashboard and click the newly generated 'MyFirstReport'
link on it. Now the renderer should start it's task and show you the expected
results.

But now the fun just starts! Try out the functions stated in the
'MyFirstReport' PDF file, to include the dynamic content in your asciidoctor
template.

Additionally you might want to make the selection of the template variable.
Piece of cake: Just add a dashboard variable to your grafana dashboard named
`template` and let the user select or enter a template name. To make use of it,
you should change the link of the 'MyFirstReport' link to
`http://<<your-server-url>>:8815/render?`

That's it. Let me know your feedback!

## Webservice overview

Running the reporter as a webservice provides the following URLs

    /overview - for all running or retained renderings
    /render - for rendering a template, 'var-template' is the only mandatory GET parameter
    /view_report - for viewing the status or receving the result of a specific rendering, is automatically called after a successfull /render call
    /cancel_report - for cancelling the rendering of a specific report, normally not called manually, but on user interaction in the /view_report or /overview URL

## Features

* Build report template including all imaginable grafana content:
  * panels as images
  * panel table query or custom query results as real document tables (not images!)
  * single panel value or custom query single value result integrated in texts
* Solid as a rock, also in case of template errors (at least it aims to be)
* Runs standalone or as a webservice
* Seamlessly integrates with asciidoctor docker container
* Developed for being able to support other tools than asciidoctor as well

## Roadmap

This is just a collection of things, I am heading for in future, without a schedule.

* Add documentation of possible asciidoctor calls to grafana
* Add documentation for configuration file
* Add a simple plugin system to support specific asciidoctor modifications
* Solve code TODOs
* Become [rubocop](https://rubocop.org/) ready

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.

Though not yet valid for my code, I'd like to see the project become
[rubocop](https://rubocop.org/) ready :-)

Definitely open spots from my side are:

* This README
* Clean and properly setup test cases
* An own webpage for this project

## Licensing

The code in this project is licensed under MIT license.

## Acknowledgements
* [asciidoctor](https://github.com/asciidoctor/asciidoctor)
* [asciidoctor-pdf](https://github.com/asciidoctor/asciidoctor-pdf)
* [grafana](https://github.com/grafana/grafana)

Inspired by [Izak Marai's grafana reporter](https://github.com/IzakMarais/reporter)

## Donations

If this project saves you as much time as I hope it does, and if you'd like to
support my work, feel free donate, even a cup of coffee is appreciated :)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=35LH6JNLPHPHQ)

