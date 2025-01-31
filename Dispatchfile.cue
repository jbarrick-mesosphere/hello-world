_tknVersion: "0.3.1"

resource "src-git": {
  type: "git"
  param url: "$(context.git.url)"
  param revision: "$(context.git.commit)"
}

resource "gitops-git": {
  type: "git"
  param url: "https://github.com/jbarrick-mesosphere/hello-world-gitops"
}

resource "docker-image": {
  type: "image"
  param url: "docker.io/mesosphere/hello-world"
  param digest: "$(inputs.resources.docker-image.digest)"
}

task "source-to-image": {
  inputs: ["src-git"]
  outputs: ["docker-image"]

  steps: [
    {
      name: "build-and-push"
      image: "chhsiao/kaniko-executor"
      args: [
        "--destination=\(resource["docker-image"].param.url)",
        "--context=/workspace/src-git",
        "--oci-layout-path=/builder/home/image-outputs/docker-image",
        "--dockerfile=/workspace/src-git/Dockerfile"
      ],
      env: [
        {
          name: "DOCKER_CONFIG",
          value: "/builder/home/.docker"
        }
      ]
    }
  ]
}

task "deploy": {
  inputs: ["docker-image", "gitops-git"]
  steps: [
    {
      name: "update-gitops-repo"
      image: "mesosphere/pumpkin-update-gitops-repo:latest"
      workingDir: "/workspace/gitops-git"
      args: [
        "-git-revision=$(context.git.commit)",
        "-docker-image-digest=$(inputs.resources.docker-image.digest)"
      ]
    }
  ]
}

actions: [
  {
    tasks: ["source-to-image", "deploy"]
    on push branches: ["master"]
  },
  {
    tasks: ["source-to-image"]
    on pull_request branches: ["master"]
  },
  {
    tasks: ["source-to-image"]
    on pull_request chatops: ["retest"]
  }
]
