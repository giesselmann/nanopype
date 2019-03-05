# Intro

* Explain briefly what comes next, what is the purpose of the modules section, etc.
* Mini summary how to enter docker because it is needed at this point already

General comments for all following modules:
* What are flags and how to set them? Like

        basecalling_albacore_barcoding: false
        basecalling_albacore_disable_filtering: true
        basecalling_albacore_flags: ''

* Make additional generic calls if multiple tools are available like

```
../<TOOL>/runs/..
OR
../<TOOL1|TOOL2|TOOL3>/runs/..
```

such that it is easy to realize where to insert other tools if preferred.

* Where to provide ```runnames.txt```?
