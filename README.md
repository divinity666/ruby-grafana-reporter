[![MIT License](https://img.shields.io/github/license/divinity666/ruby-grafana-reporter.svg?style=flat-square)](https://github.com/divinity666/ruby-grafana-reporter/blob/master/LICENSE)
[![Build Status](https://travis-ci.org/divinity666/ruby-grafana-reporter.svg?branch=master)](https://travis-ci.org/github/divinity666/ruby-grafana-reporter?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/divinity666/ruby-grafana-reporter/badge.svg?branch=master)](https://coveralls.io/github/divinity666/ruby-grafana-reporter?branch=master)
[![Gem Version](https://badge.fury.io/rb/ruby-grafana-reporter.svg)](https://badge.fury.io/rb/ruby-grafana-reporter)

# Ruby Grafana Reporter
Reporting Service for Grafana

## Table of Contents

* [About the project](#about-the-project)
* [Getting started](#getting-started)
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

Can't wait to see, what functions the reporter provides within the asciidoctor
templates? Have a look at the [function documentation](FUNCTION_CALLS.md).

The complete
[API documentation](https://rubydoc.info/gems/ruby-grafana-reporter) can be
found here.

## Getting started

There exist several ways of installing the reporter. Here I cover the easiest
setup by using ruby gems. If you need further installation help, or want to use
a "baremetal" ruby setup or a docker integration, please have a look at the more
extended [installation documentation](INSTALL.md).

To install the reporter as a gem, simply run:

    gem install ruby-grafana-reporter

If no configuration file is in place, you might want to use the configuration
wizard, which leads you through all necessary steps:

    ruby-grafana-reporter -w

It is strongly recommended, to also create the demo PDF file, as stated at the end
of the procedure, to get a detailed documentation of all the reporter capabilities.

To run the reporter as a service, you only need to call it like this:

    ruby-grafana-reporter

Neat, isn't it?

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
  * Url: `http://<<your-server-url>>:<<your-webservice-port>>/render?var-template=myfirsttemplate`
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
`http://<<your-server-url>>:<<your-webservice-port>>/render?`

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

