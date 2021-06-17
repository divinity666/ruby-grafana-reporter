[![MIT License](https://img.shields.io/github/license/divinity666/ruby-grafana-reporter.svg?style=flat-square)](https://github.com/divinity666/ruby-grafana-reporter/blob/master/LICENSE)
[![Build Status](https://travis-ci.com/divinity666/ruby-grafana-reporter.svg?branch=master)](https://travis-ci.com/github/divinity666/ruby-grafana-reporter?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/divinity666/ruby-grafana-reporter/badge.svg?branch=master)](https://coveralls.io/github/divinity666/ruby-grafana-reporter?branch=master)
[![Gem Version](https://badge.fury.io/rb/ruby-grafana-reporter.svg)](https://badge.fury.io/rb/ruby-grafana-reporter)

# Ruby Grafana Reporter
Reporting Service for Grafana

## Table of Contents

* [About the project](#about-the-project)
* [Features](#features)
* [Supported datasources](#supported-datasources)
* [Quick Start](#quick-start)
* [Grafana integration](#grafana-integration)
* [Webservice overview](#webservice-overview)
* [Roadmap](#roadmap)
* [Donations](#donations)

## About the project

[Grafana](https://github.com/grafana/grafana) is a great tool for monitoring and
visualizing data from different sources. Anyway the free version is lacking a
professional reporting functionality. And this is, where the ruby grafana reporter
steps in.

The key functionality of the reporter is to capture data and images from grafana
dashboards and to use it in your custom reports to finally create reports in PDF,
HTML, or any other format.

By default (an extended version of) Asciidoctor is enabled as template language.

## Features

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
* Supports webhook callbacks on before, on cancel and on finishing a report (see
configuration file)
* Solid as a rock, also in case of template errors and whatever else may happen
* Full [API documentation](https://rubydoc.info/gems/ruby-grafana-reporter) available

## Supported datasources

Functionalities are provided as shown here:

Database                  | Image rendering | Raw queries   | Composed queries
------------------------- | :-------------: | :-----------: | :------------:
all SQL based datasources | supported       | supported     | supported
Graphite                  | supported       | supported     | supported
InfluxDB                  | supported       | supported     | not (yet) supported
Prometheus                | supported       | supported     | n/a in grafana
other datasources         | supported       | not supported | not supported

The characteristics of a raw query are, that the query is either specified manually in
the panel specification or in the calling template.

Composed queries are all kinds of query, where the grafana UI feature (aka visual editor
mode) for query specifications are used. In this case grafana is translating the UI query
specification to a raw query, which then in fact is sent to the database.

## Quick Start

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

## Grafana integration

For using the reporter directly from grafana, you need to simply add a link to your
grafana dashboard:

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

## Webservice overview

Running the reporter as a webservice provides the following URLs

    /overview - for all running or retained renderings
    /render - for rendering a template, 'var-template' is the only mandatory GET parameter
    /view_report - for viewing the status or receving the result of a specific rendering, is automatically called after a successfull /render call
    /cancel_report - for cancelling the rendering of a specific report, normally not called manually, but on user interaction in the /view_report or /overview URL

The main endpoint to call for report generation is configured in the previous chapter [Grafana integration](#grafana-integration).

However, if you would like to see, currently running report generations and previously generated reports, you may want to call the endpoint `/overview`.

## Roadmap

This is just a collection of things, I am heading for in future, without a schedule.

* Support all grafana datasources
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

## Donations

If this project saves you as much time as I hope it does, and if you'd like to
support my work, feel free donate. :)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=35LH6JNLPHPHQ)
