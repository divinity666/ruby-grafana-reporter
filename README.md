[![MIT License](https://img.shields.io/github/license/divinity666/ruby-grafana-reporter.svg?style=flat-square)](https://github.com/divinity666/ruby-grafana-reporter/blob/master/LICENSE)
[![Build Status](https://ci.appveyor.com/api/projects/status/5ac434885onmqpm4/branch/master?svg=true)](https://ci.appveyor.com/project/divinity666/ruby-grafana-reporter/branch/master)
[![Coverage Status](https://coveralls.io/repos/github/divinity666/ruby-grafana-reporter/badge.svg?branch=master)](https://coveralls.io/github/divinity666/ruby-grafana-reporter?branch=master)
[![Gem Version](https://badge.fury.io/rb/ruby-grafana-reporter.svg)](https://badge.fury.io/rb/ruby-grafana-reporter)

# Ruby Grafana Reporter
Reporting Service for Grafana

## Table of Contents

* [About the project](#about-the-project)
* [Getting started](#getting-started)
  * [Use cases](#use-cases)
  * [Features](#features)
  * [Supported datasources](#supported-datasources)
* [Setup](#setup)
  * [Installation](#installation)
  * [Grafana integration](#grafana-integration)
* [Advanced information](#advanced-information)
  * [Webservice](#webservice)
  * [Using ERB templates](#using-erb-templates)
  * [Using webhooks](#using-webhooks)
  * [Developing your own plugin](#developing-your-own-plugin)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [Licensing](#licensing)
* [Acknowledgements](#acknowledgements)

## Your support is appreciated!

Hey there! I provide you this software free of charge. I have already
spend a lot of my private time in developing, maintaining and supporting it.

If you enjoy my work, feel free to

[![buymeacoffee](https://az743702.vo.msecnd.net/cdn/kofi3.png?v=0)](https://ko-fi.com/divinity666)

Thanks for your support and keeping this project alive!

## About the project

[Grafana](https://github.com/grafana/grafana) is a great tool for monitoring and
visualizing data from different sources. Anyway the free version is lacking a
professional reporting functionality. And this is, where the ruby grafana reporter
steps in.

The key functionality of the reporter is to capture data and images from grafana
dashboards and to use it in your custom templates to finally create reports in PDF
(default), HTML, or any other format.

By default (an extended version of) Asciidoctor is enabled as template language.

## Getting started

![GettingStarted](https://github.com/divinity666/ruby-grafana-reporter/blob/master/.assets/GettingStartedAnimation.gif)

### Use cases

* Create an automated PDF report about your server infrastructure health for your management
* Allow users to build an on-demand CSV file containing data shown on your dashboard, for further use in Excel
* Export your home meter data as a static web-page, that you can publish to the web

### Features

* Supports creation of reports for multiple [grafana](https://github.com/grafana/grafana)
dashboards (and also multiple grafana installations!) in one resulting report
* PDF (default), HTML and many other report formats are supported
* Easy-to-use configuration wizard, including fully automated functionality to create a
demo report for your dashboard
* Include dynamic content from grafana (find here a reference for all
[asciidcotor reporter calls](FUNCTION_CALLS.md)):
  * panels as images
  * tables based on grafana panel queries or custom database queries (no images!)
  * single values to be integrated in text, based on grafana panel queries or custom
database queries
* Runs as
  * webservice to be called directly from grafana
  * standalone command line tool, e.g. to be automated with `cron` or `bash` scrips
  * microservice from standard asciidoctor docker container without any dependencies
* Use webhook callbacks on before, on cancel and on finishing a report (see
configuration file) to combine them with your services
* Solid as a rock - no matter if you do mistakes in your configuration or grafana does no
longer match templates: the ruby-grafana-reporter webservice will always return properly.
* Full [API documentation](https://rubydoc.info/gems/ruby-grafana-reporter) available

### Supported datasources

Functionalities are provided as shown here:

Database                  | Image rendering | Raw queries   | Composed queries
------------------------- | :-------------: | :-----------: | :------------:
all SQL based datasources | supported       | supported     | supported
Graphite                  | supported       | supported     | supported
InfluxDB                  | supported       | supported     | supported
Prometheus                | supported       | supported     | n/a in grafana
other datasources         | supported       | not supported | not supported

The characteristics of a raw query are, that the query is either specified manually in
the panel specification or in the calling template.

Composed queries are all kinds of query, where the grafana UI feature (aka visual editor
mode) for query specifications are used. In this case grafana is translating the UI query
specification to a raw query, which then in fact is sent to the database.

## Setup


### Installation

You don't have a grafana setup runnning already? No worries, just configure
`https://play.grafana.org` in the configuration wizard and see the magic
happen!

If your grafana setup requires a login, you'll have to setup an api key for
the reporter. Please follow the steps
[described here](https://github.com/divinity666/ruby-grafana-reporter/issues/2#issuecomment-811836757)
first.

**Windows:**

* [Download latest Windows executable](https://github.com/divinity666/ruby-grafana-reporter/releases/latest)
* `ruby-grafana-reporter -w`

**Raspberry Pi:**

* `sudo apt-get install ruby`
* `gem install ruby-grafana-reporter`
* `ruby-grafana-reporter -w`

**Ruby environment:**

* `gem install ruby-grafana-reporter`
* `ruby-grafana-reporter -w`

**Docker environment** (advanced users):

* [Download latest single-rb file](https://github.com/divinity666/ruby-grafana-reporter/releases/latest)
to an empty folder
* create a configuration file by calling `ruby ruby-grafana-reporter -w` (if in doubt,
run the command within your docker container)
* create file `/<<path-to-single-rb-file-folder>>/startup.sh` with the following
content:

```
cd /documents
ruby bin/ruby-grafana-reporter
```
* add the startup script to your asciidoctor section in your docker-compose.yaml:

```
asciidoctor:
  image: asciidoctor/docker-asciidoctor
  container_name: asciidoctor
  hostname: asciidoctor
  volumes:
    - /<<path-to-single-rb-file-folder>>:/documents
  command:
    sh /documents/startup.sh
  restart: unless-stopped
```
* start/restart the asciidoctor docker container

### Grafana integration

For using the reporter directly from grafana, the reporter has to run as webservice, i.e. it has to be
called without the `-t` parameter.

If this is the case, you simply simply need add a link to your grafana dashboard:

* Open the dashboard configuration
* Select `Links`
* Select `Add`
* Fill out as following:
  * Type: `link`
  * Url: `http://<<your-server-url>>:<<your-webservice-port>>/render?var-template=demo_report`
  * Title: `Demo Report`
  * Select `Time range`
  * Select `Variable values`
* Select `Add`

Now go back to your dashboard and click the newly generated `Demo Report`
link on it. Now the renderer should start it's task and show you the expected
results.

Please note, that the reporter won't automatically refresh your screen to update
the progress. Simply hit `F5` to refresh your browser. After the report has been
successfully built, it will show the PDF after the next refresh automatically.

You want to select a template in grafana, which shall then be rendered?
Piece of cake: Just add a dashboard variable to your grafana dashboard named
`template` and let the user select or enter a template name. To make use of it,
you should change the link of the `Demo Report` link to
`http://<<your-server-url>>:<<your-webservice-port>>/render?`. On
hitting the new link in the dashboard, grafana will add the selected template as
a variable and forward it to the reporter.

## Advanced information

### Use grafana variables in templates
It is common practice to use dashboard variables in grafana, to allow users to show
the dashboard for a specific set of data only. This is where grafana variables are
used.

Those variables are then also used in panel queries, to react on selecting or entering
those variables.

You may provide those variables during report generation to the reporter. Therefore
you have to specify them in the individual calls.

Let's say, you have a variable called `serverid` in the dashboard. You may now want
to set this variable for a panel image rendering. This can be done with the following
calls:

````
grafana_panel_image:1[var-serverid=main-server]
grafana_panel_image:1[var-serverid=replica-server]
````

This will render two images: one for `main-server` and one for `replica-server`.

So, to forward grafana variables to the reporter calls, you simply have to use the
form `var-<<your-variable-name>>` and specify those in your reporter template.

### Webservice endpoints

Running the reporter as a webservice provides the following URLs

    /overview - for all running or retained renderings
    /render - for rendering a template, 'var-template' is the only mandatory GET parameter, all parameters will be passed to the report templates as attributes
    /view_report - for viewing the status or receving the result of a specific rendering, is automatically called after a successfull /render call
    /cancel_report - for cancelling the rendering of a specific report, normally not called manually, but on user interaction in the /view_report or /overview URL

The main endpoint to call for report generation is configured in the previous chapter [Grafana integration](#grafana-integration).

However, if you would like to see, currently running report generations and previously generated reports, you may want to call the endpoint `/overview`.

### Using ERB templates

By default the configuration wizard will setup the reporter with the asciidoctor
template language enabled. For several reasons, you may want to take advantage of
the ruby included
[ERB template language](https://docs.ruby-lang.org/en/master/ERB.html).

Anyway you should consider, that ERB templates can include harmful code. So make
sure, that you will only use ERB templates in a safe environment.

To enable the ERB template language, you need to modify your configuration file
in the section `grafana-reporter`:

````
grafana-reporter:
  report-class: GrafanaReporter::ERB::Report
````

Restart the grafana reporter instance, if running as webservice. That's all.

In ERB templates, you have access to the variables `report`, which is a reference
to the currently executed
[ERB Report object](https://rubydoc.info/gems/ruby-grafana-reporter/GrafanaReporter/ERB/Report)
and `attributes`, which contains a hash
of variables, which have been handed over to the report generations, e.g. from
a webservice call.

To test the configuration, you may want to run the configuration wizard again,
which will create an ERB template for you.

### Using webhooks

Webhooks provide an easy way to get automatically informed about the progress
of a report. The nice thing is, that this is completely independent from
running the reporter as webservice, i.e. these callbacks are also called if you
run the reporter standalone.

To use webhooks, you have to specify, in which progress states of a report you
are interested. Therefore you have to configure it in the `grafana-reporter`
section of your configuration file, e.g.

````
grafana-reporter:
  callbacks:
    all:
      - http://<<your_callback_url>>
````

Remember to restart the reporter, if it is running as a webservice.

After having done so, your callback url will be called for each event with
a JSON body including all necessary information of the report. For details see
[callback](https://rubydoc.info/gems/ruby-grafana-reporter/GrafanaReporter/ReportWebhook#callback-instance_method).

### Developing your own plugin

The reporter is designed to allow easy integration of your own plugins,
without having to modify the reporter base source on github (or anywhere
else). This section shows how to implement and load a custom datasource.

Implementing a custom datasource is needed, if you use a custom datasource
grafana plugin, which is not yet supported by the reporter. In that case you
can build your own custom datasource for the reporter and load it on demand
with a command line parameter, without having to build your own fork of this
project.

This documentation will provide a simple, but mocked implementation of an
imagined grafana datasource.

First of all, let's create a new text file, e.g. `my_datasource.rb` with the
following content:

````
class MyDatasource < ::Grafana::AbstractDatasource
  def self.handles?(model)
    tmp = new(model)
    tmp.type == 'my_datasource'
  end

  def request(query_description)
    # see https://rubydoc.info/gems/ruby-grafana-reporter/Grafana/AbstractDatasource#request-instance_method
    # for detailed information of given parameters and expected return format

    # TODO: call your datasource, e.g. via REST call
    # TODO: return the value in the needed format
  end

  def raw_query_from_panel_model(panel_query_target)
    # TODO: extract or build the query from the given grafana panel query target hash
  end

  def default_variable_format
    # TODO, specify the default variable format
    # see https://rubydoc.info/gems/ruby-grafana-reporter/Grafana/Variable#value_formatted-instance_method
    # for detailed information.
  end
end
````

The only thing left to do now, is to make this datasource known to the
reporter. This can be done with the `-r` command line flag, e.g.

````
ruby-grafana-reporter -r my_datasource.rb
````

The reporter implemented some magic, to automatically register datasource
implementations on load, if they inherit from `::Grafana::AbstractDatasource`.
This means, that you don't have to do anything else here.

Now the reporter knows about your datasource implementation and will use it,
if you request information from a panel, which is linked to the type
`my_datasource` as specified in the `handles?` method above. If any errors
occur during execution, the reporter will catch them and show them in the error
log.

Registering a custom ruby file is independent from running the reporter as a
webservice or as a standalone executable. In any case the reporter will apply
the file.

Technically, loading your own plugin will call require for your ruby file,
_after_ all reporter files have been loaded and _before_ the execution of the
webservice or a rendering process starts.

## Roadmap

This is just a collection of things, I am heading for in future, without a schedule.

* Support grafana internal datasources
* Support additional templating variable types
* Solve code TODOs
* Become [rubocop](https://rubocop.org/) ready

## Contributing

If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome.

## Licensing

The code in this project is licensed under MIT license.

## Acknowledgements
* [asciidoctor](https://github.com/asciidoctor/asciidoctor)
* [asciidoctor-pdf](https://github.com/asciidoctor/asciidoctor-pdf)
* [grafana](https://github.com/grafana/grafana)

Inspired by [Izak Marai's grafana reporter](https://github.com/IzakMarais/reporter)
