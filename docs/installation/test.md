# Tests

* Restructure such that calls are in the beginning
* Make a generic call like ```test/test_rules.py test_unit_rules.<CASE>```

From the Nanopype repository run either all or only a subset of the available tests:
### Python

    python3 test/test_rules.py
    python3 test/test_rules.py test_unit_rules.test_storage

### Docker

    docker run -it giesselmann/nanopype
    cd /app
    python3 test/test_rules.py
    python3 test/test_rules.py test_unit_rules.test_flappie


To test if the installation and configuration was successful, we provide a small MinION dataset of a human cell line. The available test cases are:

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


The test takes ~20 min on 4 cores and downloads ~54 MB reference sequence for the alignment module.
Tests cover all modules of the pipeline, if some tools (e.g. albacore) are not installed, the associated tests will fail. Independent parts of the pipeline will however still work.
Note that test runtimes are not representative due to very small batch sizes.
