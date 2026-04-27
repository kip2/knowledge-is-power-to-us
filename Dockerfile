# Quartz サイトをビルド/プレビューするための最小ランタイム。
# docker-compose.yml が bind mount で動かす前提なので、ソースコードはイメージに焼かない。
# 必要なツール（Node 22 / git / rsync / bash）だけ追加し、それ以外は素のまま。

FROM node:22-bookworm-slim

# bootstrap.sh が git clone、sync.sh が rsync を呼ぶため両方必須。
# bash は node:bookworm-slim に同梱されているが念のため保証。
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        rsync \
        bash \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 実行コマンドは docker-compose.yml の各サービスで指定する。
CMD ["bash"]
