# Ruby Grafana Reporter
(Asciidoctor) Reporter Service for Grafana

Did you ever want to create (professional) reports based on Grafana dashboards?
I did so in order to being able to automatically get monthly reports of my
home's energy usage. That's how it started.

The reporter provides a full extension setup for the famous Asciidoctor and can
perfectly integrate in a docker environment.

As a result of the reporter, you receive PDF documents or any other format that
is supported by Asciidoctor.

## Installing / Getting started

Essentially there are two ways of using it: either on top of a vanilla ruby
installation, or as an addon to the asciidoctor docker image. For the second
case, there is no need to install further dependencies, as it is designed to
work without any modifications there.

To install on a plain ruby installation, follow these steps:

Make sure a proper ruby environment with gem is setup. Check with:

```ruby -v
gem -v````

Install asciidoctor

```gem install asciidoctor asciidoctor/extensions asciidoctor-pdf```

Download the ruby grafana reporter and unpack to a folder of your choice, e.g.
`ruby-grafana-reporter`.

To check if all dependencies are setup properly, run

```ruby ruby-grafana-reporter/bin/ruby-grafana-reporter.rb -h```

### Initial Configuration

Create a first configuration file, named e.g. `myconfig` with the following
content:

```grafana-reporter:
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
```

Check out if the configuration is valid and your grafana instance can be accessed
properly:

```ruby myconfig --test default```

### Example render

Create a first asciidoctor template file in your `templates-folder`, e.g.
`myfirsttemplate.adoc` with the following content:

```= First Ruby Grafana Reporter Example

include::grafana_help[]

include::grafana_environment[]
```

Now you're ready to go! Let's check it out:

```ruby ruby-grafana-reporter/bin/ruby-grafana-reporter.rb myconfig --template
myfirsttemplate.adoc --output myfirstrender.pdf```

You should now find a PDF document named `myfirstrender.pdf` which includes a detailed
help page on how to use the ruby grafana reporter functions in asciidoctor, as well
as a list of all environment variables that can be accessed.

## Features

* Integrate grafana panel images, grafana panel query results as table or single values,
custom SQL query results as tables, alers, annotations and many more
* Solid as a rock, also in case of template errors (at least it aims to be)
* Runs standalone or as a webservice
* Seamlessly integrates with asciidoctor docker container
* Developed for being able to support other tools than asciidoctor as well

## Roadmap

This is just a collection of things, I am heading for in future, without a schedule.

* Add documentation on how to integrate with asciidoctor docker container
* Share (anonymized) rspec tests in this repo
* Add a simple plugin system to support specific asciidoctor modifications
* Solve code TODOs
* Improve this documentation
* Improve rspec tests
* Become `rubocop` ready

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.

Though not yet valid for my code, I'd like to see the project become `rubocop`
ready :-)

## Licensing

The code in this project is licensed under MIT license.

## Acknowledgements
* [asciidoctor](https://github.com/asciidoctor/asciidoctor)
* [asciidoctor-pdf](https://github.com/asciidoctor/asciidoctor-pdf)

Inspired by [Izak Marai's grafana reporter](https://github.com/IzakMarais/reporter)

## Donations

If this project saves you as much time as I hope it does, and if you'd like to
support my work, feel free donate, even a cup of coffee is appreciated :)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](35LH6JNLPHPHQ)
