# YAML/XML/TOML Prettier based on `yq`

[`yq`](https://github.com/kislyuk/yq) is Command-line YAML, XML, TOML processor - `jq` wrapper for YAML/XML/TOML documents.

That pre-commit-hook was designed, firstly as auto-alphabetize YAML list hooks, but also support usage in `raw_yq` mode - where you do what you want providing fully custom args to `yq`.

* [How to install](#how-to-install)
  * [1. Install dependencies](#1-install-dependencies)
  * [2. Install the pre-commit hook globally](#2-install-the-pre-commit-hook-globally)
  * [3. Add configs and hooks](#3-add-configs-and-hooks)
  * [4. Run](#4-run)
* [Glossary](#glossary)
* [Available modes/presets](#available-modespresets)
  * [Alphabetization mode](#alphabetization-mode)
  * [Use hook in `raw_yq` mode](#use-hook-in-raw_yq-mode)
* [Authors](#authors)
* [License](#license)

Want to contribute? Check [open issues](https://github.com/SpotOnInc/pre-commit-yq/issues?q=-label%3A%22auto-update%22+is%3Aopen+sort%3Aupdated-desc) and [contributing notes](/.github/CONTRIBUTING.md).

## How to install

### 1. Install dependencies

<!-- markdownlint-disable no-inline-html -->

* [`pre-commit`](https://pre-commit.com/#install),
  <sub><sup>[`git`](https://git-scm.com/downloads),
  <sub><sup>POSIX compatible shell,
  <sub><sup>Internet connection (on first run),
  <sub><sup>x86_64 compatible operation system,
  <sub><sup>Some hardware where this OS will run,
  <sub><sup>Electricity for hardware and internet connection,
  <sub><sup>Some basic physical laws,
  <sub><sup>Hope that it all will work.
  </sup></sub></sup></sub></sup></sub></sup></sub></sup></sub></sup></sub></sup></sub></sup></sub></sup></sub><br><br>
* `bash` 4 or higher
* `patch` 2.5.8 or higher, 2.7.6+ preferred
* [`yq`](https://github.com/kislyuk/yq#installation) OR [`docker`](https://docs.docker.com/get-docker/) <sub><sup>or both</sup></sub>

    If both are installed, hook prefers locally installed `yq`.


<details><summary><b>MacOS</b></summary><br>

```bash
brew install pre-commit bash yq gpatch
```

</details>

<details><summary><b>Ubuntu 20.04</b></summary><br>

```bash
sudo apt update
sudo apt install -y unzip software-properties-common python3 python3-pip
python3 -m pip install --upgrade pip
pip3 install --no-cache-dir pre-commit
sudo apt install -y yq
```

</details>

<details><summary><b>Windows 10/11</b></summary>

We highly recommend using [WSL/WSL2](https://docs.microsoft.com/en-us/windows/wsl/install) with Ubuntu and following the Ubuntu installation guide.

> Note: We won't be able to help with issues that can't be reproduced in Linux/Mac.
> Please try to find a working solution and send a PR before opening an issue.

Otherwise, you can follow [this gist](https://gist.github.com/etiennejeanneaurevolve/1ed387dc73c5d4cb53ab313049587d09):

1. Install [`git`](https://git-scm.com/downloads) and [`gitbash`](https://gitforwindows.org/)
2. Install [Python 3](https://www.python.org/downloads/)
3. Install all prerequisites needed (see above)

Ensure your PATH environment variable looks for `bash.exe` in `C:\Program Files\Git\bin` (the one present in `C:\Windows\System32\bash.exe` does not work with `pre-commit.exe`)

</details>

<!-- markdownlint-enable no-inline-html -->

### 2. Install the pre-commit hook globally

> Note: not needed if you use the Docker image

```bash
DIR=~/.git-template
git config --global init.templateDir ${DIR}
pre-commit init-templatedir -t pre-commit ${DIR}
```

### 3. Add configs and hooks

Step into the repository you want to have the pre-commit hooks installed and run:

```bash
git init
cat <<EOF > .pre-commit-config.yaml
repos:
- repo: https://github.com/SpotOnInc/pre-commit-yq
  rev: <VERSION> # Get the latest from: https://github.com/SpotOnInc/pre-commit-yq/releases
  hooks:
    - id: yq_yaml_prettier
EOF
```

### 4. Run

Execute this command to run `pre-commit` on all files in the repository (not only changed files):

```bash
pre-commit run -a
```

## Glossary

`yq PATH` - here is PATH to the object inside file, supported by `yq`.

In example, YAML representation of:

```yaml
components:
  terraform:
    okta-groups-teleport:
```
In `yq PATH` is `.components.terraform.okta-groups-teleport`.


## Available modes/presets

### Alphabetization mode

To make all your YAML list in alphabetical order, just add to `.pre-commit-config.yaml` next:

```yaml
- repo: <REPO>
  rev: <VERSION> # Get the latest from: <REPO>/releases
  hooks:
    - id: yq_yaml_prettier
```

If you'd to like specify only one `yq PATH` which should be alphabetized in the file:

1. Add a flag `-s` (`--sort-path`) in `args:` section

> **Note**: `2.` don't work in most cases. That's a bug, which could be fixed by rewriting hook to Python/JS and remove `yq` at all.

2. In the same line, provide `Key`=`Value`, where `Key` is path to file from repo root, and `Value` is [golang regex](https://github.com/google/re2/wiki/Syntax) which check [`yq PATH`](#glossary-before-we-start) and includes `yq PATH`'es which pass regex:

```yaml
- name: Alphabetize YAML arrays
  id: yq_yaml_prettier
  args:
    - -s okta/teleport.yaml=^.components.terraform|name$
    - -s another/file.yml=.foo.bar
```



### Use hook in `raw_yq` mode

You can provide any valid [`yq` expression](https://mikefarah.gitbook.io/yq/operators):

1. Add a flag `-r` (`--raw-yq`) in `args:` section
2. In the same line, provide inputs for `yq`


For example, next is identical to hook without any args

```yaml
- name: Describe here what you do
  id: yq_yaml_prettier
  args:
    - -r -i '( ... |select(type == "!!seq")) |= sort_by( select(tag == "!!str") //  (keys | .[0]) )'
```

To only display changes, in the example above replace `-i` with `-P`.

> **WARNING**: When `-r` specifued, all `-s` flags in current hook call will be ignored.

---

Also, you can change on which [`files`](https://pre-commit.com/#config-files) you'd like to run hook (default - "any YAML") and which you want `exclude`.

```yaml
- id: yq_yaml_prettier
  ...
  files: \.(ya?ml)$
  exclude: |
    (?x)
      # Do not touch pre-commit related files
      (^.pre-commit
      # Fails on YAML-templates extensions
      |^helmfiles
      |/templates/
    )
```

> More about regular expressions in pre-commit you can read [here](https://pre-commit.com/#regular-expressions). In two words, that is Python [`re.VERBOSE`](https://docs.python.org/3/library/re.html#re.VERBOSE).

## Authors

This repository is managed by SpotOn OSS team with help from these awesome contributors:

<!-- markdownlint-disable no-inline-html -->
<a href="https://github.com/SpotOnInc/pre-commit-yq/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=SpotOnInc/pre-commit-yq" />
</a>
<!-- markdownlint-enable no-inline-html -->

Additional thanks to [`pre-commit-terraform` hooks contributors](https://github.com/antonbabenko/pre-commit-terraform#authors).

## License

MIT licensed. See [LICENSE](LICENSE) for full details.
