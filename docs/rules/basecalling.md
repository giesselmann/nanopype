# Basecalling

The basecaller translates the raw electrical signal from the sequencer into a nucleotide sequence in fastq format. As input the **fast5** files as provided by the [storage](storage.md) module are required.

In order to process the output of one flow cell with the basecaller *guppy* run from within your processing directory:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/guppy/WA01/batches/20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.fastq.gz

Providing a *runnames.txt* with one run name per line it is possible to process multiple flow cells at once and merge the output into a single file e.g.:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences/guppy/WA01.fastq.gz

The tag *WA01* is arbitrary and may describe a corresponding experiment or cell line.

## Folder structure

The basecalling module can create the following file structure relative to the working directory:

```sh
|--sequences/
   |--guppy/                                                 # Guppy basecaller
      |--batches/
         |--WA01/
            |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01/
               |--0.fastq.gz                                 # Sequence batches
               |--1.fastq.gz
                ...
            |--20180101_FAH12345_FLO-MIN106_SQK-LSK108_WA01.fastq.gz
      |--WA01.fastq.gz
   |--flappie/                                               # Flappie basecaller
      |--...
```

## Cleanup

The batch processing output of the basecalling module can be cleaned up by running:

    snakemake --snakefile /path/to/nanopype/Snakefile sequences_clean

This will delete all files and folders inside of any **batches** directory and should only be used at the very end of an analysis workflow. The alignment module for instance relies on the single batch sequence files.

## Tools
Depending on the application you can choose from one of the following basecallers, listed with their associated configuration options. All tools share the following configuration options:

```
threads_basecalling: 4
```
### Albacore
The ONT closed source software based on a deep neural network. The installer is accessible after login to the community board. Albacore is deprecated!

```
basecalling_albacore_barcoding: false
basecalling_albacore_disable_filtering: true
basecalling_albacore_flags: ''
```

### Guppy
Current state of the art basecaller.

```
basecalling_guppy_config: 'dna_r9.4.1_450bps_fast.cfg'
basecalling_guppy_qscore_filter: 0
basecalling_guppy_flags: ''
```

#### GPU Acceleration

Guppy basecalling is an order of magnitude faster when running on a GPU. Nanopype supports different models of GPU accelerated basecalling, from local single device to distributed multi device environments. GPU basecalling is currently only possible with the [source](../installation/src.md) installation of the pipeline!

!!! error "guppy version"
    ONT deploys two builds of guppy, CPU and GPU based. Nanopype installs and uses the CPU version per default. To enable the accelerated workflow, you have to manually download and install the guppy GPU build. From the nanopore community, get the ```ont-guppy_3.x.y_linux64.tar.gz```, extract and overwrite the *guppy_basecaller* and *guppy_basecall_server* executables installed by Nanopype. Alternatively install the GPU version to a separate directory and change the **env.yaml** of Nanopype accordingly.

**1. Local single GPU**

The easiest setup is to run nanopype on a single server with one GPU. To enable it, change the guppy command line flags to:

```
basecalling_guppy_flags: '-x cuda:0'
```

You will need to experiment with the *--num_callers* and *--gpu_runners_per_device* command line flags to maximize the device utilization (monitor with nvidia-smi).

To avoid multiple jobs starting and possibly interfering on the same GPU, you will have to limit resources. Each guppy basecall job requires 1 GPU and snakemake can constrain any type of resource per workflow (The *--resources* flag needs to be at the end of the command line):

```
snakemake --snakefile /path/to/nanopype/Snakefile sequences/albacore/WA01.fastq.gz --resources GPU=1
```


**2. Local multi-GPU**

To coordinate usage of multiple GPUs we use the **guppy_basecall_server**. The server needs to be started manually and kept alive for the entire pipeline run. To start a basecall server on GPU 0 execute the following command in a separate shell:

```
guppy_basecall_server -c dna_r9.4.1_450bps_hac.cfg --port 9000 --num_callers 8 --ipc_threads 16 --device cuda:0 --log_path ~/log/guppy_0
```

You can start multiple servers on multiple GPUs with different ports and log directories. The *nanopype.yaml* configuration file supports a list of available basecalling servers. With a single server you can simply expand the guppy_flags:

```
basecalling_guppy_flags: '--port localhost:9000'
```

For multiple instances use the *basecalling_guppy_server* config option. A *--port* flag in the guppy_flags will always overwrite this list!

```
basecalling_guppy_server:
  - 'localhost:9000'
  - 'localhost:9001'
```

For instances running on the same computer use 'localhost:port'. Please note the quotation marks around each list element.

Currently nanopype uses a simple round-robin scheduling and assigns each batch a basecall server at startup. This does not guarantee that all servers are fully utilized and will be targeted in future optimizations.

For the moment you can overload the servers by e.g. spawning two basecall servers on two GPUs, but starting snakemake with `--resources GPU=8`. Like this multiple clients will connect to each server and reduce idle times between jobs.


**3. Remote single- and multi-GPU**

Finally you may want to use multiple GPU servers in a distributed setup. The concept remains the same, start guppy_basecall_server instances on each node and configure nanopype via the *basecalling_guppy_server* option.

```
basecalling_guppy_server:
  - 'server0:9000'
  - 'server1:9001'
  - 'server1:9002'
```

If the servers are not accessible via hostname and port, consider a port forwarding via ssh:

```
ssh -v -L 9001:localhost:9001 -L 9002:localhost:9002 server1
```

Keep in mind that there is overhead of encrypting the raw data for the tunnel with this setup.

### Flappie
The experimental neural network caller from ONT using flip-flop basecalling.

```
basecalling_flappie_model: 'r941_5mC'
basecalling_flappie_flags: ''
```
