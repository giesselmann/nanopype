# Tests

After installation and [environment](configuration.md) configuration the successful setup can be tested with sample data included in the pipeline repository.

An initial test validates the presence of all required tools. This is only required for [source](src.md) installations and to check if manual e.g. albacore installations are found correctly. The test will check all supported tools, if you do not plan to use parts of the pipeline, you can ignore failing test cases.

    python3 test/test_install.py

If a tool is not correctly installed, the output lists failed test cases. If you don't plan to use these, you can safely ignore the messages.

```
F.......................
======================================================================
FAIL: test_binary_albacore (__main__.test_case_binary)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "test/test_install.py", line 66, in fn
    self.fail('{} is not executable or found in PATH'.format(self.binary_path))
AssertionError: read_fast5_basecaller.py is not executable or found in PATH

----------------------------------------------------------------------
Ran 24 tests in 0.119s

FAILED (failures=1)
```

Secondly the functionality of the pipeline itself can be tested on a small sample data set. This process is automated on [Travis-CI](https://travis-ci.org/github/giesselmann/nanopype), the commands below are meant to troubleshoot local installations.

[![Build Status](https://travis-ci.org/giesselmann/nanopype.svg?branch=master)](https://travis-ci.org/giesselmann/nanopype)

The tests are grouped by sequencing data type and pipeline module. The available data types are:

* DNA
* cDNA
* mRNA

The available test modules are:

* storage
* basecalling
* alignments
* methylation
* sv
* transcript_isoforms
* report

Not every module is tested for each data type. To run the tests a small dataset (~40MB) and the expected pipeline output are downloaded from our [webserver](https://owww.molgen.mpg.de/~nanopype/unit_tests/).

**Singularity**

```
cd /path/to/nanopype
python3 test/test_function.py DNA basecalling ~/tmp/nanopype_unit_tests --singularity
python3 test/test_function.py cDNA all ~/tmp/nanopype_unit_tests --singularity
```

**Source**

```
cd /path/to/nanopype
python3 test/test_function.py DNA basecalling ~/tmp/nanopype_unit_tests
python3 test/test_function.py mRNA all ~/tmp/nanopype_unit_tests
```

**Docker**

```
cd /path/to/nanopype
docker run --mount type=bind,source=$(pwd),target=/app nanopype/nanopype:latest python3 test/test_function.py DNA basecalling /test
docker run --mount type=bind,source=$(pwd),target=/app nanopype/nanopype:latest python3 test/test_function.py mRNA all /test
```
