#!/bin/bash
# Script to deploy a very simple web application.
# The web app has a customizable image and some text.


cat << EOM > /var/www/html/index.html
<html>
  <head><title>Meow!</title></head>
  <body>
  <div style="width:800px;margin: 0 auto">

  <!-- BEGIN -->
  <center><img src="${PLACEHOLDER}" width="${WIDTH} height="${HEIGHT}"></img></center>
  <center><h1>GitHub Actions과 HashiCorp Vault를 활용하여 안전한 GitOps Workflow 만들기</h1></center>
  HashiCorp Snapshot에 오신 것을 환영합니다. <p>
  이번 세션에서는 안전한 파이프라인 구축을 위해 HashiCorp Vault와 GitHub Actions를 사용하여 최신 GitOps Workflow 적용방안을 알아봅니다.
  <p>
  Application Name: "${PREFIX}"_app <p>
  <style type="text/css">
.tg  {border-collapse:collapse;border-spacing:0;}
.tg td{border-color:black;border-style:solid;border-width:1px;font-family:Arial, sans-serif;font-size:14px;
  overflow:hidden;padding:10px 5px;word-break:normal;}
.tg th{border-color:black;border-style:solid;border-width:1px;font-family:Arial, sans-serif;font-size:14px;
  font-weight:normal;overflow:hidden;padding:10px 5px;word-break:normal;}
.tg .tg-0lax{text-align:left;vertical-align:top}
</style>
<table class="tg">
<thead>
  <tr>
    <th class="tg-0lax">Name</th>
    <th class="tg-0lax">Value from Vault</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td class="tg-0lax">Region</td>
    <td class="tg-0lax">${REGION}</td>
  </tr>
  <tr>
    <td class="tg-0lax">PLACEHOLDER</td>
    <td class="tg-0lax">${PLACEHOLDER}</td>
  </tr>
  <tr>
    <td class="tg-0lax">WIDTH</td>
    <td class="tg-0lax">${WIDTH}</td>
  </tr>
  <tr>
    <td class="tg-0lax">HEIGHT</td>
    <td class="tg-0lax">${HEIGHT}</td>
  </tr>
</tbody>
</table>
  <!-- END -->

  </div>
  </body>
</html>
EOM

echo "Script complete."
