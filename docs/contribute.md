# Contribution

Nanopype is a growing open source project for nanopore sequencing data processing. While we continuously improve and expand the pipeline external contributions are always welcome and appreciated.


## Guidelines

These are mostly guidelines, not rules. Use your best judgment and most importantly: There's nothing you can do wrong [^1].

### Reporting Bugs

**Before submitting a Bug Report**

:   * Check in our [Release Notes](release-notes.md), if you're running the most recent version of Nanopype and if the bug you encounter was already mentioned here. Consider updating, if a new version is available.
    * (Re-)Run the module [tests](installation/test.md) for your installation. Also automated on Travis-CI, the tests help us to distinguish between problems caused by the local environment, the input data or by the pipeline implementation.
    * Search the github [issues](https://github.com/giesselmann/nanopype/issues) to see if the problem was already reported. If it has and the issue is open, leave a comment instead of opening a new one.

**Submitting a (good) Bug Report**

Explain the problem and include additional details to help maintainers reproduce the problem:

:   * Use one of the provided templates if appropriate.
    * Use a **clear and descriptive** title.
    * Describe the **exact steps** which reproduce the problem with as many details as possible.
    * Describe the behavior you **observed** and what exactly is the problem with that.
    * Describe the behavior you **expected** to see instead.
    * If the problem is related to the **cluster** execution, does it occur when running **locally**?
    * Attach any **log files** and full command line **output** as (zipped) text files.

Include details about your configuration and environment:

:   * Which version of Nanopype are you using?
    * Which of the installation methods are you using?
    * What is your operating system?
    * Which changes to the **nanopype.yaml** and **env.yaml** have you made?


### Suggesting Enhancements

**Submitting a (good) Enhancement Suggestion**

:   * Use a **clear and descriptive** title for the issue.
    * Provide a **step-by-step description** of the suggested enhancement in as many details as possible.
    * Describe the **current** behavior and explain which behavior you **expected** to see instead and why.
    * Explain why this enhancement would be **useful** to more Nanopype users


### Writing Your Contribution

Unsure where to begin? Look for issues labeled as *good first issue* or *help wanted* and articulate you wish to help.

Already a pro? Fork the repository, suggest your enhancement with an issue and start coding.

The following guide aims to keep up Nanopype's quality and provide a stable pipeline.

:   * Follow the coding style of python and snakemake files
    * If you add new files include the copyright and license header. Complete the contents, description and restrictions fields.
    * Use descriptive commit messages and group functional changes into individual commits.
    * Reference pull requests or issues after the commit title

Finally consider a rebase and create a pull-request for your feature branch against the Nanopype development branch.

## Contributors

A big **thank you** to everyone writing code for Nanopype:

* Sara Hetzel (sarahet)
* Miguel Machado (miguelpmachado)


[^1]: Our contribution guidelines are inspired by the ones from [Atom](https://github.com/atom/atom/blob/master/CONTRIBUTING.md).
