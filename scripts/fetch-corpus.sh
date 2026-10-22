#!/usr/bin/env bash
# Builds the public no-gesture corpus: openly licensed Wikimedia Commons videos of people on video
# calls, podcasts and interviews (talking with their hands, typing, drinking), reduced to landmark
# streams in corpus/public/*.lmkz. The videos stay in .build/corpus-videos and are never committed.
# Needs curl and ffmpeg. Usage: scripts/fetch-corpus.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VIDEOS=.build/corpus-videos
OUT=corpus/public
mkdir -p "$VIDEOS" "$OUT"
COMMONS=https://upload.wikimedia.org/wikipedia/commons

# name|licence|path under Commons (a transcode where Commons has one)|Commons file page
CLIPS=(
  "glam-wiki-call|CC BY 4.0|transcoded/3/31/Global_GLAM_Wiki_call_20.webm/Global_GLAM_Wiki_call_20.webm.480p.vp9.webm|File:Global_GLAM_Wiki_call_20.webm"
  "css-podcast-090|CC BY 3.0|transcoded/7/7b/The_CSS-Podcast_%E2%80%93_090_%E2%80%93_Scroll-driven_animations.webm/The_CSS-Podcast_%E2%80%93_090_%E2%80%93_Scroll-driven_animations.webm.720p.vp9.webm|File:The_CSS-Podcast_–_090_–_Scroll-driven_animations.webm"
  "sopa-wiki-podcast-1|CC BY 3.0|transcoded/b/b4/Sopa_Wiki_Podcast_-_Epis%C3%B3dio_1_-_Tecnologias_justas_para_uma_internet_livre.webm/Sopa_Wiki_Podcast_-_Epis%C3%B3dio_1_-_Tecnologias_justas_para_uma_internet_livre.webm.720p.vp9.webm|File:Sopa_Wiki_Podcast_-_Episódio_1_-_Tecnologias_justas_para_uma_internet_livre.webm"
  "fbi-podcast|Public domain|transcoded/7/70/Inside_the_FBI_Podcast_%E2%80%93_Top_Ten_Fugitive_Yulan_Adonay_Archaga_Carias.webm/Inside_the_FBI_Podcast_%E2%80%93_Top_Ten_Fugitive_Yulan_Adonay_Archaga_Carias.webm.720p.vp9.webm|File:Inside_the_FBI_Podcast_–_Top_Ten_Fugitive_Yulan_Adonay_Archaga_Carias.webm"
  "royal-society-interview|CC BY 3.0|transcoded/9/99/Interview_on_extreme_weather_with_physical_geographer_Hannah_Cloke_%E2%80%93_The_Royal_Society.webm/Interview_on_extreme_weather_with_physical_geographer_Hannah_Cloke_%E2%80%93_The_Royal_Society.webm.720p.vp9.webm|File:Interview_on_extreme_weather_with_physical_geographer_Hannah_Cloke_–_The_Royal_Society.webm"
  "teacher-interview|CC0|transcoded/d/d1/Interview_with_a_Teacher_-_Glen_Caruso.webm/Interview_with_a_Teacher_-_Glen_Caruso.webm.720p.vp9.webm|File:Interview_with_a_Teacher_-_Glen_Caruso.webm"
)

swift build -c release -q --product handyctl
HANDYCTL=$(swift build -c release --show-bin-path)/handyctl

for entry in "${CLIPS[@]}"; do
  IFS='|' read -r name licence path page <<<"$entry"
  target="$OUT/$name.lmkz"
  [[ -s "$target" ]] && { echo "have $name"; continue; }
  [[ -s "$VIDEOS/$name.webm" ]] || curl -fsSL --retry 3 -A "handy-corpus-fetch/0.1" -o "$VIDEOS/$name.webm" "$COMMONS/$path"
  [[ -s "$VIDEOS/$name.mp4" ]] || ffmpeg -loglevel error -y -i "$VIDEOS/$name.webm" -an \
    -vf "fps=30,scale='min(1280,iw)':-2" -c:v libx264 -preset veryfast -pix_fmt yuv420p -crf 23 "$VIDEOS/$name.mp4"
  "$HANDYCTL" video "$VIDEOS/$name.mp4" -o "$target" \
    --source "https://commons.wikimedia.org/wiki/$page ($licence), no-gesture footage" >/dev/null
  echo "built $name ($licence)"
done
