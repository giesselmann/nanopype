# Tests

After installation and [environment](configuration.md) configuration the successful setup can be tested with sample data included in the pipeline repository.

An initial test validates the presence of all required tools. This is only required for [source](src.md) installations and to check if manual e.g. albacore installations are found correctly. The test will check all supported tools, if you do not plan to use parts of the pipeline, you can ignore failing test cases.

    python3 test/test_install.py

Secondly the functionality of the pipeline itself is tested on a small sample data set. The command is slightly different depending on the installation method:

**Singularity**

```
cd /path/to/nanopype
python3 test/test_rules.py test_unit_singularity.<CASE>
```

**Source**

```
cd /path/to/nanopype
python3 test/test_rules.py test_unit_src.<CASE>
```

**Docker**

```
docker run -it giesselmann/nanopype
python3 /app/test/test_rules.py test_unit_src.<CASE>
```

Available test cases are:

**Storage**
:   * test_storage

**Basecalling**
:   * test_guppy
    * test_albacore
    * test_flappie

**Alignment**
:   * test_minimap2
    * test_graphmap
    * test_ngmlr

**Methylation**
:   * test_nanopolish

**Structural Variation**
:   * test_sniffles

To run all test call the test script without any test case. The test takes ~20 min on 4 cores and downloads ~54 MB reference sequence for the alignment module. Tests cover all modules of the pipeline, if some tools (e.g. albacore in the Docker container) are not installed, the associated tests will fail. Independent parts of the pipeline will however still work. Note that test run times are not representative due to very small batch sizes.
