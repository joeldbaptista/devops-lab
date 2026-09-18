# 011 — How to transfer the image to the instance and run it

This note records the last step of the lab: moving the dockerised Python
application from the control node to the EC2 instance and running it there. It
also records the two application faults that the step exposed.

Note 010 left Docker installed on the instance. So this note assumes `make play`
in `ansible/` has already succeeded.

## The transport decision

The image travels as a gzipped tar archive over SSH. No registry is involved.
The three options considered, and this list is exhaustive for this lab:

1. `docker save` on the control node, copy, `docker load` on the instance. This
   is what the lab does. It needs nothing beyond SSH, which already works.
2. Push to Amazon ECR and pull on the instance. This needs a repository, an IAM
   role on the instance, and a login step, so it adds three moving parts for one
   host.
3. Copy `main.py` and the `Dockerfile` and build on the instance. This avoids
   the archive, but then the instance needs a build toolchain and the artefact
   run in production differs from the artefact tested locally.

Option 1 costs one 44 MB transfer per deployment, which is acceptable for a
single instance.

## Why a shell script and not Ansible

The deployment is driven by `app/deploy.sh`, a shell script that calls `scp` and
`ssh` directly, and `app/run-remote.sh` runs an image already in place. Ansible
is deliberately not used for either.

The reason is the difference between the two kinds of work. Ansible converges a
machine towards a described state, and installing packages and enabling a
service fit that model, which is why `site.yml` owns them. Shipping an artefact
and running it once is an ordered sequence of imperative steps with no state to
converge, so expressing it as a role would report a change on every run and would
add a layer that explains nothing.

The cost of the decision is one duplication: the script has to know the SSH user
and the private key path, which `ansible.cfg` also holds. The defaults sit at the
top of the script and both are overridable.

## Fault 1 — the application did not compile

The first local run failed:

```
TabError: inconsistent use of tabs and spaces in indentation (main.py, line 42)
```

Line 42 is the `time.sleep(sleep_seconds)` call inside `run`. It was indented
with two tab characters while the rest of the function used spaces. The fix
replaced the tabs with spaces.

The important detail is when the fault appeared. `docker build` succeeded
throughout, because the `Dockerfile` only copies `main.py` and never imports it,
so nothing compiles the module at build time. Python raises `TabError` when it
first parses the file, which happens when the container starts. A build that
succeeds therefore says nothing about whether the application runs.

## Fault 2 — the trailing sleep

Note 008 records that the application waits 10 seconds between iterations and
not after the last one. The code did wait after the last one, so the note and
the code disagreed. The code now matches the note: `run` sleeps only while a
further iteration remains.

The printed output is unchanged, because the timestamps were already 10 seconds
apart. Only the total run time changes, and it drops by 10 seconds.

## The pieces

```sh
app/Makefile           # build, run, save, deploy, run-remote, clean
app/deploy.sh          # ships the archive, loads it, runs the container
app/run-remote.sh      # runs an image already on the instance
app/remote-common.sh   # defaults and helpers the two scripts share
app/dist/              # the archive, gitignored
```

`remote-common.sh` is sourced, never executed. It holds the defaults, the
address lookup, and thin `remote_ssh` and `remote_scp` wrappers, so neither
script repeats the SSH options or the Terraform call. Splitting it out was worth
one extra file, because the alternative was about thirty duplicated lines.

`make save` writes `app/dist/ec2-lab-app-latest.tar.gz`. That path is gitignored,
because a 44 MB build artefact does not belong in the repository.

### deploy.sh

It performs seven steps, and this list is complete:

1. Check that the archive exists, and name `make save` in the error when it does
   not. This runs first, because it is the cheapest check.
2. Read the instance address from `terraform -chdir=../terraform output -raw
   public_ip`, unless `-H` pinned one. So Terraform stays the single source of
   truth for the address, exactly as the generated Ansible inventory does.
3. Create `/home/ec2-user/app` on the instance over SSH.
4. `scp` the archive into it.
5. Check that `docker` exists on the instance, and name `make play` in the error
   when it does not.
6. `docker load` the archive, then compare the image architecture against the
   instance architecture.
7. `docker run --rm` the image with the requested iteration count.

Steps 5 to 7 run on the instance, inside a quoted heredoc piped to `bash -s`.
Quoting the heredoc delimiter stops the local shell expanding anything inside
it, so the three values it needs arrive as positional arguments instead. None of
them contains whitespace, which is what makes that safe.

The script uses `set -euo pipefail`, and the remote half sets it again, because
the remote shell is a separate process that inherits no options.

Nothing in the script uses `sudo`. So a successful run is also evidence that the
`docker` group membership from note 009 took effect, because `ec2-user` reaches
the daemon socket without it.

### run-remote.sh

It runs the image that is already on the instance, and it ships nothing. So it
is the quick way to exercise the image again, or to run it with a different
iteration count, without moving 44 MB for a second time.

It resolves the address the same way, then checks two things on the instance
before running anything: that `docker` exists, and that the image is present.
The second check matters more than it looks. Without it, `docker run` treats an
absent image as one to fetch, so it contacts Docker Hub, and the failure then
names a registry rather than the real cause.

The script announces the address locally and announces the run itself from the
instance, after both checks pass. So a failure never follows a line claiming the
container is running.

## Run it

```sh
cd app
make deploy        # build, ship, and run
make run-remote    # run what is already there
```

`make deploy` depends on `save`, so it builds the image, writes the archive, and
then runs `./deploy.sh`. Running the two halves separately is equivalent:

```sh
make save
./deploy.sh
```

`make run-remote` depends on nothing, so it neither rebuilds nor ships. Use it
after a `make deploy`, and use `make deploy` again once the image changes.

`deploy.sh` takes six options, and this list is complete: `-H` an address, `-i`
the iteration count, `-a` an archive path, `-k` an SSH private key, `-u` an SSH
user, and `-h` the usage message. `run-remote.sh` takes the same options except
`-a`, which it has no use for. The environment variables `IMAGE`, `TAG`,
`ITERATIONS`, `SSH_USER`, `SSH_KEY`, `TF_DIR`, and `REMOTE_DIR` set the same
values, and an option wins over the matching variable.

```sh
./deploy.sh -i 5                 # five timestamps
./run-remote.sh -i 5             # the same, without shipping the archive
./deploy.sh -H 203.0.113.4       # skip the Terraform lookup
make run-remote ITERATIONS=5     # the same through make
```

The application waits 10 seconds between iterations and not after the last one,
so both scripts block for roughly `10 × (iterations - 1)` seconds.

## The architecture check

`t4g.micro` is arm64, so the image must be arm64. Two guards cover this:

- `app/Makefile` builds with `--platform linux/arm64`, so the archive is arm64
  even when the control node is not.
- Step 6 compares the architecture from `docker image inspect` against `uname
  -m` on the instance. Docker and `uname` spell the same architecture
  differently, `arm64` against `aarch64`, so the script translates between them
  before comparing.

Without the check, a mismatch surfaces as `exec format error` from `docker run`,
which does not name the cause.

## The archive is reproducible, and why that was worth doing

Two changes make the same image produce a byte-identical archive every time.

First, `gzip` records the compression time in its header, so the build now pipes
through `gzip -n`, which omits that timestamp.

Second, `docker build` attaches a provenance attestation by default, and that
attestation carries the build time. The build now passes `--provenance=false`.

With both in place, two consecutive `make save` runs produce the same SHA-256:

```
7036c2d77aefe3e72f371d82dbbe228b6c514d614dbd2f809a9b66ffbc8da4f6
7036c2d77aefe3e72f371d82dbbe228b6c514d614dbd2f809a9b66ffbc8da4f6
```

The script does not use that property yet, because `scp` transfers the file
whether or not it changed. So every `make deploy` moves 44 MB. Two ways to avoid
that, and they are mutually exclusive alternatives: compare a remote `sha256sum`
against the local one and skip the copy when they match, or use `rsync` in place
of `scp`. Neither is implemented, because one transfer to one host is not worth
the extra code here.

What the property does give is a check that costs nothing: the same image always
has the same checksum, so the archive on the instance can be compared against
the local one directly.

## The image id differs between the two daemons

The same image reports different ids on the two machines:

```
control node:  sha256:13426b0d7e0b...   214MB
instance:      sha256:7f450026f019...   152MB
```

Both values are correct, and the cause is the image store. The control node runs
Docker 28.4.0 with the containerd image store, which reports the manifest digest
as the id and counts uncompressed content. The instance runs Docker 25.0.14 with
the classic store, which reports the image config digest, the value the build
prints as `exporting config sha256:...`. So comparing ids across the two daemons
proves nothing; comparing the archive checksum does.

## Verified on 2026-09-14

Against instance `i-04500c3b68fd0db17` at `3.249.172.199`, a `t4g.micro` running
`aarch64` with Docker 25.0.14. `make deploy` produced:

```
IMAGE=ec2-lab-app TAG=latest ./deploy.sh -i 3
shipping ec2-lab-app-latest.tar.gz (46344962 bytes) to ec2-user@3.249.172.199
Loaded image: ec2-lab-app:latest
loaded ec2-lab-app:latest (arm64), running it with 3 iterations
1/3 2026-09-14T15:54:17+00:00
2/3 2026-09-14T15:54:27+00:00
3/3 2026-09-14T15:54:37+00:00
```

The timestamps are 10 seconds apart, which is the interval the application is
specified to keep.

`make run-remote` produced:

```
IMAGE=ec2-lab-app TAG=latest ./run-remote.sh -i 2
using ec2-user@3.249.172.199
running ec2-lab-app:latest with 2 iterations
1/2 2026-09-14T16:09:49+00:00
2/2 2026-09-14T16:09:59+00:00
```

Each failure path of both scripts was exercised as well, and this list is
complete:

- A missing archive exits 1 and names `make save`.
- A `TF_DIR` holding no state exits 1 and names `make apply` and `-H`.
- An image absent from the instance exits 1 and names `make deploy`. Tested with
  `IMAGE=nosuch ./run-remote.sh`.
- An unknown option exits 2 and prints the usage message.
- `-h` prints the usage message and exits 0.

The remote check for `docker` was not exercised in either script, because the
instance already carries it. So that one branch is unverified.

Observed on the instance afterwards:

```sh
ansible ec2 -m command -a 'docker images ec2-lab-app'
ansible ec2 -m command -a 'ls -lh /home/ec2-user/app'
ansible ec2 -m shell -a 'df -h / | tail -1'
```

- `ec2-lab-app latest 7f450026f019 152MB`.
- `ec2-lab-app-latest.tar.gz`, 45M, owned by `ec2-user`.
- The 8 GiB root volume is 31% used, so the image and the archive together leave
  ample room.

The container exits on its own, and `--rm` removes it, so nothing is left
running between deployments.

## Rebuilding the instance

A destroyed and rebuilt instance starts bare, so the full sequence from nothing
is:

```sh
cd terraform && make apply     # create the instance
cd ../ansible && make play     # utilities and Docker
cd ../app && make deploy       # the application image and one run
```

The first two steps are idempotent. The third is not, and it is not meant to be,
because it runs the container every time.

## Next

Nothing. This was the last step of the lab. Note 006 covers destroying the
instance, which is what to do when the sandbox is no longer needed, because a
running `t4g.micro` and its EBS volume are billed whether or not anything uses
them.
