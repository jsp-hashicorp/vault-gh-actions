#!/bin/bash
# Script to deploy a very simple web application.
# The web app has a customizable image and some text.

cat << EOM > /var/www/html/index.html
<html>
  <head><title>Meow!</title></head>
  <body>
  <div style="width:800px;margin: 0 auto">

  <!-- BEGIN -->
  <center><img src="${PLACEHOLDER}" width="${WIDTH} height="${height}"></img></center>
  <center><h1>GitHub Actions과 HashiCorp Vault를 활용하여 안전한 GitOps Workflow 만들기</h1></center>
  HashiCorp Snapshot에 오신 것을 환영합니다. <p>
  이번 세션에서는 안전한 파이프라인 구축을 위해 HashiCorp Vault와 GitHub Actions를 사용하여 최신 GitOps Workflow 적용방안을 알아봅니다.
  Application Name: "${PREFIX}"_app <p>
  Read From Vault Key/Value <p>
  AWS Access Secret 
  <!-- END -->

  </div>
  </body>
</html>
EOM

echo "Script complete."
