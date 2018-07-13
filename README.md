
# gitlab-runner

## Start and register a runner

It seems most recent version of gitlab-runner's build process can't see host's environment variables such as JAVA_HOME or CI_INFRA_OPT_GIT_AUTH_TOKEN.
You can add environment variables at Repository->Settings->CI/CD Pipelines->Secret Variables.

<del>
1. CI_INFRA_OPT_GIT_AUTH_TOKEN

OSS's ci script need the CI_INFRA_OPT_GIT_AUTH_TOKEN to access script or configuration in internal or private repository.

- Get CI_INFRA_OPT_GIT_AUTH_TOKEN from gitlab:

  From git service page (e.g. gitlab: http(s)://gitlab.local:10080/profile/personal_access_tokens page).

- CI_INFRA_OPT_GIT_AUTH_TOKEN need to be set before container start by `export CI_INFRA_OPT_GIT_AUTH_TOKEN=<your_CI_INFRA_OPT_GIT_AUTH_TOKEN>`.
</del>

## Start and register a runner on raw machine

2. Prepare directories and files on host
```
docker run --privileged=true --rm -v /var/run/docker.sock:/var/run/docker.sock busybox chmod a+rw /var/run/docker.sock
docker run --privileged=true --rm -v /var/run/docker.sock:/var/run/docker.sock busybox ls -l /var/run/docker.sock
```

Gitlab can not distribute settings and keys like jenkins, need to mount or download manually 
(e.g. maven's ~/.m2/settings-security.xml or git deploy key).

3. Run `docker-compose up -d`

4. Find token for runner.
Shared: Goto admin/runners page (e.g. http(s)://gitlab.local:10080/admin/runners).
Specific: Goto repo's settings/ci_cd page (e.g. http(s)://gitlab.local:10080/<namespace>/<repo>/settings/ci_cd).

5. Run `docker exec -it gitlab-runner.local sudo gitlab-runner register` and input following info (in <>).
```
Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
<e.g. http://gitlab.local:10080/>
Please enter the gitlab-ci token for this runner:
<Token found in step 4>
Please enter the gitlab-ci description for this runner:
<gitlab-runner-<ip>>
Please enter the gitlab-ci tags for this runner (comma separated):
<gitlab-runner>
Whether to run untagged builds [true/false]:
<true>
Whether to lock Runner to current project [true/false]:
<false>
Registering runner... succeeded runner=********
Please enter the executor: parallels, virtualbox, shell, ssh, docker+machine, docker-ssh+machine, kubernetes, docker, docker-ssh:
<shell>
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
```

## Start and register a runner on k8s

2. Prepare directories and files on host

- This should be done by a cron script on host that fix permission of '/var/run/docker.sock' periodically

3. put CI_INFRA_OPT_GIT_AUTH_TOKEN into gitlab-runner/k8s/gitlab-runner-secret.yaml by
- `export CI_INFRA_OPT_GIT_AUTH_TOKEN=<your_CI_INFRA_OPT_GIT_AUTH_TOKEN>`
- `sed "s#<PUT_BASE64_CI_INFRA_OPT_GIT_AUTH_TOKEN_HERE_MANUALLY>#$(echo -n ${CI_INFRA_OPT_GIT_AUTH_TOKEN} | base64 -w 0)#" gitlab-runner-secret.template > gitlab-runner-secret.yaml`

4. Run `kubectl cluster-info` check that kubectl is properly configured

- `kubectl create -f gitlab-runner-secret.yaml` and `kubectl create -f gitlab-runner-deploy.yaml` to deploy
- `kubectl get po` to see gitlab-runner's pod
- `kubectl exec -it gitlab-runner-<suffix> bash` to get in gitlab-runner's pod
- `chown -R gitlab-runner:gitlab-runner /home/gitlab-runner` to ensure directory's permission

5. Run `kubectl exec -it gitlab-runner-<suffix> gitlab-runner register`
   and input same info as previous section (Start and register a runner on raw machine)

## Advanced configuration (config.toml)
Use `CONFIG_FILE` environment variable specify a configuration file.
[Official doc for config.toml](https://docs.gitlab.com/runner/configuration/advanced-configuration.html)

```
# e.g. set concurrent to 3
docker exec -it gitlab-runner.local /bin/sed -Ei 's#^concurrent = [0-9]+$#concurrent = 3#g' /etc/gitlab-runner/config.toml
```

## Note
- gitlab-runner's version must compatible with gitlab service.

- Container instance needs to access docker (/var/run/docker.sock) on host.
```
sudo chmod a+rw /var/run/docker.sock
```

- When register a runner "Whether to run untagged builds" should be true.

- You can inspect container by:
```
docker exec -it gitlab-runner.local cat /etc/gitlab-runner/config.toml
docker exec -it gitlab-runner.local cat /home/gitlab-runner/.gitlab-runner/config.toml
docker exec -it gitlab-runner.local cat /home/gitlab-runner/.ssh/config
docker exec -it gitlab-runner.local ls -la /home/gitlab-runner/.ssh
docker exec -it gitlab-runner.local ls -la /home/gitlab-runner/.docker
```


- ERROR: Uploading artifacts to coordinator... too large archive  id=116 responseStatus=413

https://gitlab.com/gitlab-org/gitlab-ce/issues/20612
![](src/site/markdown/images/gitlab-runner-max-artifacts-size.png)

- ERROR: 403
Cloning repository...
Cloning into '/home/gitlab-runner/builds/b3ef1983/0/contextPath/group/repository'...
remote: Git access over HTTP is not allowed
fatal: unable to access 'https://gitlab-ci-token:xxxxxxxxxxxxxxxxxxxx@domain/contextPath/group/repository.git/': The requested URL returned error: 403
ERROR: Job failed: exit status 1

see: https://gitlab.com/gitlab-org/gitlab-ce/issues/22501

### see: https://gitlab.com/gitlab-org/gitlab-runner/issues/1884

Clone manually

in project's `.gitlab-ci.yml`
```yaml
before_script:
- export GIT_STRATEGY=none
```

### see: https://stackoverflow.com/questions/39208420/how-do-i-enable-cloning-over-ssh-for-a-gitlab-runner

Copy ssh key into container
```bash
docker exec gitlab-runner.local sh -c "echo HOME \$HOME"
docker exec gitlab-runner.local sh -c "ls -la ~/.ssh; cat ~/.ssh/config"
docker cp ~/.ssh/id_rsa gitlab-runner.local:/var/lib/gitlab-runner/.ssh/id_rsa
docker exec gitlab-runner.local sh -c "sudo chown gitlab-runner:gitlab-runner ~/.ssh/id_rsa; ls -la ~/.ssh"
```

Edit /etc/gitlab-runner/config.toml
```
docker exec -it gitlab-runner.local /bin/bash
sudo vi /etc/gitlab-runner/config.toml
```

Add:
```
  [runners.ssh]
    user = "git"
    identity_file = "/home/gitlab-runner/.ssh/id_rsa
```
Make it looks like this:
```
[[runners]]
  name = "<name>"
  url = "<url>"
  token = "<token>"
  executor = "shell"
  [runners.ssh]
    host = "<git-service>"
    user = "git"
    identity_file = "/home/gitlab-runner/.ssh/id_rsa"
```
If Edit /etc/gitlab-runner/config.toml not working, do git fetch in scripts of `.gitlab-ci.yml`
