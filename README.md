[![MIT License](https://img.shields.io/github/license/divinity666/ruby-grafana-reporter.svg?style=flat-square)](https://github.com/divinity666/ruby-grafana-reporter/blob/main/LICENSE)

# Ruby Grafana Reporter
(Asciidoctor) Reporter Service for Grafana

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

## Documentation

Find the complete
[API documentation](https://rubydoc.info/gems/ruby-grafana-reporter) here.

## Installing

There exist several ways of installing the reporter. All of them have in
common, that they require a working ruby environment. Check with the following
commands, that the tools are setup and run properly:

   ruby -v
   gem -v

Download the ruby grafana reporter to a folder of your choice.

You may want to use the single file application as well. BTW, you may build
your own single file application by calling

    ruby bin/get_single_file_application.rb

### Barebone ruby installation

To install on a plain ruby installation, follow these steps:

Install asciidoctor

    gem install asciidoctor asciidoctor-pdf zip

or simply use

    bundle install

To check if all dependencies are setup properly, run the following command
in that folder:

    ruby bin/ruby-grafana-reporter.rb -h

### GEM installation

To install as a gem, simply run:

    gem install ruby-grafana-reporter

To see if it works properly, you may run:

    irb
    require 'ruby-grafana-reporter'
    GrafanaReporter::Application::Application.new.configure_and_run

The gem installation might mainly be interesting, if you would like to use the
reporter as a library and include it in other application setups.

### Docker integration

Essentially you need to make the application available within your asciidoctor
docker container and run the following command

    ruby bin/ruby-grafana-reporter.rb -h

If you are unsure, on how to make it available in the container, you may refer
to the information in chapter 'Run as a service' for the docker integration
below.

## Initial Configuration

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

Check out if the configuration is valid and your grafana instance can be accessed
properly.

### Barebone ruby installation

    ruby bin/ruby-grafana-reporter.rb myconfig --test default

### GEM installation

    require 'ruby-grafana-reporter'
    GrafanaReporter::Application::Application.new.configure_and_run(["myconfig", "--test", "default"])

### Docker integration

Same as in barebone ruby installation. Make sure you are running the command
from inside the container, e.g. by using `docker exec`.

## Hello World example

Create a first asciidoctor template file in your `templates-folder`, e.g.
`myfirsttemplate.adoc` with the following content:

    = First Ruby Grafana Reporter Example
    
    include::grafana_help[]

    include::grafana_environment[]

Now you're ready to go! Let's check it out!

### Barebone ruby installation

    ruby bin/ruby-grafana-reporter.rb myconfig --template myfirsttemplate.adoc --output myfirstrender.pdf

You should now find a PDF document named `myfirstrender.pdf` which includes a detailed
help page on how to use the ruby grafana reporter functions in asciidoctor, as well
as a list of all environment variables that can be accessed.

### GEM installation

    require 'ruby-grafana-reporter'
    GrafanaReporter::Application::Application.new.configure_and_run(["myconfig", "--template", "myfirsttemplate.adoc", "--output", "myfirstrender.pdf"])

### Docker integration

Same as in barebone ruby installation. Make sure you are running the command
from inside the container, e.g. by using `docker exec`.

## Run as a service

Running the reporter as a webservice provides the following URLs

    /render - for rendering a template
    /overview - for all running or retained renderings
    /view_report - for viewing the status or receving the result of a specific rendering
    /cancel_report - for cancelling the rendering of a specific report

### Barebone ruby installation

    ruby bin/ruby-grafana-reporter.rb myconfig

Test your configuration by requesting the following URL in a browser of your
choice:

    http://<<your-server-url>>:8815/render?var-template=myfirsttemplate.adoc

### GEM installation

    require 'ruby-grafana-reporter'
    GrafanaReporter::Application::Application.new.configure_and_run(["myconfig"])

Test your configuration by requesting the following URL in a browser of your
choice:

    http://<<your-server-url>>:8815/render?var-template=myfirsttemplate.adoc

### Docker integration

Assuming you have a `docker-compose` setup running, you may want to add the
following to your services secion in your `docker-compose.yml`:

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

## Features

* Integrate grafana panel images, grafana panel query results as table or single values,
custom SQL query results as tables, alers, annotations and many more
* Solid as a rock, also in case of template errors (at least it aims to be)
* Runs standalone or as a webservice
* Seamlessly integrates with asciidoctor docker container
* Developed for being able to support other tools than asciidoctor as well

## Roadmap

This is just a collection of things, I am heading for in future, without a schedule.

* Add documentation for configuration file
* Share (anonymized) rspec tests in this repo
* Add a simple plugin system to support specific asciidoctor modifications
* Solve code TODOs
* Become [rubocop](https://rubocop.org/) ready

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.

Though not yet valid for my code, I'd like to see the project become
[rubocop](https://rubocop.org/) ready :-)

## Licensing

The code in this project is licensed under MIT license.

## Acknowledgements
* [asciidoctor](https://github.com/asciidoctor/asciidoctor)
* [asciidoctor-pdf](https://github.com/asciidoctor/asciidoctor-pdf)

Inspired by [Izak Marai's grafana reporter](https://github.com/IzakMarais/reporter)

## Donations

If this project saves you as much time as I hope it does, and if you'd like to
support my work, feel free donate, even a cup of coffee is appreciated :)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=35LH6JNLPHPHQ)

