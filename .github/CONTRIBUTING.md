# Notes for contributors

* [Run and debug hooks locally](#run-and-debug-hooks-locally)
* [Add new hook](#add-new-hook)
  * [Before writing code](#before-writing-code)
  * [Prepare basic documentation](#prepare-basic-documentation)
  * [Add code](#add-code)
  * [Finish with the documentation](#finish-with-the-documentation)

## Run and debug hooks locally

```bash
pre-commit try-repo {-a} /path/to/local/pre-commit-terraform/repo {hook_name}
```

I.e.

```bash
pre-commit try-repo /mnt/c/Users/tf/pre-commit-terraform terraform_fmt # Run only `terraform_fmt` check
pre-commit try-repo -a ~/pre-commit-terraform # run all existing checks from repo
```

Running `pre-commit` with `try-repo` ignores all arguments specified in `.pre-commit-config.yaml`.

If you need to test hook with arguments, follow [pre-commit doc](https://pre-commit.com/#arguments-pattern-in-hooks) to test hooks.

For example, to test that the [`terraform_fmt`](../README.md#terraform_fmt) hook works fine with arguments:

```bash
/tmp/pre-commit-yq/hooks/yq_yaml_prettier.sh --args="-r -i '( ... |select(type == \"!!seq\")) |= sort_by( select(tag == \"!!str\") //  (keys | .[0]) )'" test-dir/foo.yaml test-dir/bar.yaml
```


## Add new hook

### Before writing code

1. Try to figure out future hook usage.
2. Confirm the concept with SpotOn OSS team.

### Prepare basic documentation

1. Identify and describe dependencies in [Install dependencies](../README.md#1-install-dependencies)

### Add code

1. Add new hook to [`.pre-commit-hooks.yaml`](../.pre-commit-hooks.yaml)
2. Create hook file. Don't forget to make it executable via `chmod +x /path/to/hook/file`.
3. Test hook. How to do it is described in [Run and debug hooks locally](#run-and-debug-hooks-locally) section.
4. Test hook one more time.
    1. Push commit with hook file to GitHub
    2. Grab SHA hash of the commit
    3. Test hook using `.pre-commit-config.yaml`:

        ```yaml
        repos:
        - repo: https://github.com/SpotOnInc/pre-commit-yq # Your repo
        rev: 3d76da3885e6a33d59527eff3a57d246dfb66620 # Your commit SHA
        hooks:
          - id: new_hook # New hook name
            args:
              - --args=--config=.docs.yml # Some args that you'd like to test
        ```

### Finish with the documentation

Create and populate a new hook section in [README](../README.md) which will include the hook description and usage examples.
