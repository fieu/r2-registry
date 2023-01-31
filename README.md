<h1 align="center">
  <br>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://i.imgur.com/FKEZkXk.png">
    <img alt="Text changing depending on mode.'" src="https://i.imgur.com/OTDvrDp.png">
    </picture>
  <br>
  <br>
</h1>

<h4 align="center">Docker image registry on Cloudflare R2 (No workers)</h4>

<p align="center">
  <img src="https://img.shields.io/badge/GNU%20Bash-4EAA25?style=for-the-badge&logo=GNU%20Bash&logoColor=white" alt="Built with Bash">
  <img src="https://img.shields.io/badge/Docker-2CA5E0?style=for-the-badge&logo=docker&logoColor=white" alt="Made for Docker">
  <img src="https://img.shields.io/badge/Cloudflare-F38020?style=for-the-badge&logo=Cloudflare&logoColor=white" alt="Built with Cloudflare R2">
</p>

<br>

# 📖 About

This is a very simple Bash shell script that converts local Docker container images into the registry distribution format and structure. The tool then uploads that structure via `rclone` to your R2 bucket of choice. The end result is having a Docker registry compatible URL on R2.

Example URL: `docker pull pub-6975b173047b49bf97e9146ff7808721.r2.dev/myapp:v1.0.0`
Example URL with custom domain: `docker pull images.sheldon.is/myapp:v1.0.0`

# 📕 Requirements

- [skopeo](https://github.com/containers/skopeo/blob/main/install.md) - Toolkit for container images
- [rclone](https://rclone.org) - Upload container image structure to R2
- [jq](https://stedolan.github.io/jq/) - CLI utility for handling JSON data

# ⛔️ Limitations

Most notably, read-only access to images.

Jérome (who inspired this all-in-one script) goes over the other limitations of using a static-file-like-host such as R2 [here](https://github.com/jpetazzo/registrish#limitations).

# ⌨️ Usage

First, build your Docker image as you normally would.

1. `cd myapp`
2. `docker build -t myapp .`
3. `docker tag myapp:latest myapp:v1.0.0`

Next, install r2-registry:

1. `git clone https://github.com/fieu/r2-registry`
2. `cd r2-registry`
3. `./generate.sh [image] [tag]`

Now, setup your environment variables that are used by the script:

- `CLOUDFLARE_ACCOUNT_ID` - Cloudflare account ID (found [here](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/find-account-and-zone-ids/))
- `R2_BUCKET` - Name of R2 bucket to store image contents
- `R2_ACCESS_KEY_ID` - R2 Access Key ([info](https://developers.cloudflare.com/r2/data-access/s3-api/tokens/))
- `R2_SECRET_ACCESS_KEY` - R2 Secret Access Key ([info](https://developers.cloudflare.com/r2/data-access/s3-api/tokens/))
- `R2_DOMAIN` - R2 custom domain (optional) ([info](https://developers.cloudflare.com/r2/data-access/public-buckets/#custom-domains))

## 🧪 Example

```sh
export CLOUDFLARE_ACCOUNT_ID=123456789
export R2_BUCKET=docker-images
export R2_ACCESS_KEY_ID=123
export R2_SECRET_ACCESS_KEY=123
export R2_DOMAIN=images.sheldon.is
./generate.sh myapp v1.0.0
```

## 🧬 Output

![Example GIF](https://i.imgur.com/UoTlgOg.gif)

## 🍿 Try it out

Try and pull my image from my R2 bucket:

```sh
docker pull images.sheldon.is/myapp:v1.0.0
```

## ❓ Help

```sh
$ ./generate.sh
Usage: ./generate.sh <image> <tag>
	image (string)	 The name of the image to build
	tag (string)	 The tag of the image to build
```

# ✏️ Contributing

Contributions are **welcome** and will be fully **credited**.

I accept contributions within project scope via Pull Requests on [GitHub](https://github.com/fieu/r2-registry).

# 👤 Credits

[jpetazzo/registrish](https://github.com/jpetazzo/registrish) - Initial concept and code snippets

# 📝 License

r2-registry is open-sourced software licensed under the [MIT License](https://github.com/fieu/r2-registry/blob/master/LICENSE).
