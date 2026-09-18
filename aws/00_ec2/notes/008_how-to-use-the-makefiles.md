# 008 — How to use the Makefiles

Two Makefiles exist, one per component, and each one wraps the commands recorded
in the earlier notes. Neither knows about the other, so each is run from its own
directory.

```sh
app/Makefile         # builds and runs the dockerised Python application
terraform/Makefile   # manages the AWS resources
```

A Makefile recipe must be indented with a tab character, never with spaces. So
an editor that converts tabs to spaces breaks the file, and `make` then reports
`missing separator`.

## terraform/Makefile

```sh
cd terraform
make            # same as make plan, because plan is the default goal
make init       # download providers, write the lock file
make fmt        # rewrite the .tf files in canonical style
make validate   # syntax and type checks, no AWS calls
make plan       # runs validate first, then shows what apply would do
make apply      # create the resources, with Terraform's confirmation prompt
make output     # re-print the outputs of the last apply
make ssh        # log in to the instance
make status     # ask AWS what exists
make destroy    # remove the resources, with Terraform's confirmation prompt
make clean      # remove .terraform/ and any saved plan file
```

The default goal is `plan`, so a bare `make` never changes anything.

Five variables are overridable at the command line: `TF` (default `terraform`),
`AWS` (default `aws`), `PROJECT` (default `devops-lab-ec2`), `SSH_KEY` (default
`~/.ssh/devops-lab-ec2`), and `SSH_USER` (default `ec2-user`).

`apply` and `destroy` keep the interactive confirmation. Pass `AUTO_APPROVE=1` to
add `-auto-approve`:

```sh
make apply AUTO_APPROVE=1
```

Four design points worth remembering:

- `plan` depends on `validate`, so a type error is caught before Terraform
  contacts AWS.
- `ssh` resolves the address at run time, inside the recipe, rather than when
  `make` parses the file. So the target fails cleanly when nothing is applied,
  instead of breaking every other target in the file.
- `status` asks AWS, while `output` asks the local state file. The two disagree
  after a stop and start, because that changes the public IP without changing
  the state.
- `clean` deliberately leaves `terraform.tfstate` in place. Deleting the state
  would orphan live AWS resources, as note 005 explains. So `clean` removes only
  `.terraform/`, which is roughly 790 MB of providers, and any `*.tfplan` file.
  Run `make init` afterwards.

## app/Makefile

```sh
cd app
make            # same as make build
make build      # docker build -t $(IMAGE):$(TAG) .
make run        # docker run --rm $(IMAGE):$(TAG) $(ITERATIONS)
make clean      # remove the image, then remove __pycache__
```

Four variables are overridable: `IMAGE` (default `ec2-lab-app`), `TAG` (default
`latest`), `ITERATIONS` (default `3`), and `DOCKER` (default `docker`).

```sh
make run ITERATIONS=5
make build IMAGE=myapp TAG=v1
```

The application sleeps 10 seconds between iterations and not after the last one,
so `make run ITERATIONS=5` takes about 40 seconds.

In `clean`, the image removal line is prefixed with `-`, which tells `make` to
ignore a failure on that line. So `make clean` still succeeds when the image was
never built.

## Verified on 2026-09-14

Every target in both files was expanded with `make -n`, which prints the
commands without running them. The read-only Terraform targets `fmt`, `validate`,
`output`, and `status` were also run for real.

Docker is not installed on this machine, so no target in `app/Makefile` has been
executed. They are unverified beyond their expansion.

## Next

Install Docker on the instance with Ansible.

## Addendum, 2026-09-14

Three points in this note were overtaken by later work, and this list is
complete.

A third Makefile exists, `ansible/Makefile`. It was added with the Ansible
configuration and it is documented in note 009.

`app/Makefile` gained three targets, `save`, `deploy`, and `run-remote`, which
note 011 covers:

```sh
make save         # build, then docker save | gzip -n > dist/...
make deploy       # save, then ./deploy.sh, which ships and runs the image
make run-remote   # ./run-remote.sh, which runs the image already on the instance
make clean        # now also removes dist/
```

`run` and `run-remote` differ only in where the container runs, and both honour
`ITERATIONS`.

`build` also gained two flags, `--platform linux/arm64` and
`--provenance=false`. Note 011 explains why each is needed. A fifth overridable
variable, `PLATFORM`, accompanies the first of them.

Finally, the claim above that no target in `app/Makefile` had been executed no
longer holds. Docker was installed on the control node on 2026-09-14, and
`build`, `run`, `save`, `deploy`, `run-remote`, and `clean` were all run for real
that day.
