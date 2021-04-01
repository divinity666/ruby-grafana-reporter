[![MIT License](https://img.shields.io/github/license/divinity666/ruby-grafana-reporter.svg?style=flat-square)](https://github.com/divinity666/ruby-grafana-reporter/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/divinity666/ruby-grafana-reporter.svg?branch=master)](https://travis-ci.org/github/divinity666/ruby-grafana-reporter?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/divinity666/ruby-grafana-reporter/badge.svg?branch=master)](https://coveralls.io/github/divinity666/ruby-grafana-reporter?branch=master)
[![Gem Version](https://badge.fury.io/rb/ruby-grafana-reporter.svg)](https://badge.fury.io/rb/ruby-grafana-reporter)

# Ruby Grafana Reporter
Reporting Service for Grafana

## Table of Contents

* [About the project](#about-the-project)
* [Features](#features)
* [Quick Start](#quick-start)
* [Grafana integration](#grafana-integration)
* [Webservice overview](#webservice-overview)
* [Roadmap](#roadmap)
* [Donations](#donations)

## About the project

Did you ever want to create (professional) reports based on Grafana dashboards?
I did so in order to being able to automatically get monthly reports of my
home's energy usage. That's how it started.

## Features

* Build PDF reports based on [grafana](https://github.com/grafana/grafana) dashboards
(other formats supported)
* Include dynamic content from grafana (see [function documentation](FUNCTION_CALLS.md)
as a detailed reference):
  * panels as images
  * tables based on grafana panel queries or custom database queries (no images!)
  * single values to be integrated in text, based on grafana panel queries or custom
database queries
* Multi purpose use of the reporter
  * webservice to be called directly from grafana - it also runs without further
dependencies in the standard asciidoctor docker container!
  * standalone command line tool, e.g. to be automated with cron or bash scrips
* Comes with a complete configuration wizard, including functionality to build a
demo report on top of the configured grafana host
* Solid as a rock, also in case of template errors and whatever else may happen

## Quick Start

You don't have a grafana setup runnning already? No worries, just configure
`https://play.grafana.org` in the configuration wizard and see the magic
happen for that!

If your grafana setup requires a login, you'll have to setup an api key for
the reporter. Please follow the steps
[described here](https://github.com/divinity666/ruby-grafana-reporter/issues/2#issuecomment-811836757)
first.

**Windows:**
- [Download latest Windows executable](https://github.com/divinity666/ruby-grafana-reporter/releases/latest)
- `ruby-grafana-reporter -w`

**Raspberry Pi:**
- `sudo apt-get install ruby`
- `gem install ruby-grafana-reporter`
- `ruby-grafana-reporter -w`

**Ruby environment:**
- `gem install ruby-grafana-reporter`
- `ruby-grafana-reporter -w`

**Docker environment** (advanced users):
- [Download latest single-rb file](https://github.com/divinity666/ruby-grafana-reporter/releases/latest)
to an empty folder
- create a configuration file by calling `ruby ruby-grafana-reporter -w` (if in doubt,
run the command within your docker container)
- create file `/<<path-to-single-rb-file-folder>>/startup.sh` with the following
content:
```
cd /documents
ruby bin/ruby-grafana-reporter
```
- add asciidoctor your compose yaml:
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
- start/restart the asciidoctor docker container

## Grafana integration

The key feature of the report is, that it can easily be integrated with grafana.

For accessing the reporter from grafana, you need to simply add a link to your
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

* Support table/single value renderings also for non-sql databases
* Clean and properly setup test environment (currently it's a real mess...)
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
support my work, feel free donate, even a cup of coffee is appreciated :)

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate?hosted_button_id=35LH6JNLPHPHQ)
