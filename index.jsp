<%--
    Document   : index
    Created on : 2015-10-6, 23:38:01
    Author     : air
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title>Dependency Tree Annotate Tool</title>
        <link href="./css/bootstrap.min.css" rel="stylesheet">
        <script src="./js/jquery-1.7.2.min.js"></script>
        <script src="./js/bootstrap.min.js"></script>
        <script src="./js/FileSaver.min.js"></script>
        <style media="screen" type="text/css">
            .picture {
                position: relative;
            }
            .mybar, .blob1, .blob2 {
                position: absolute;
                left: 150px;
            }
            .blob1 {
                top: 30px;
            }
            .mybar {
                top: 70px;
            }
            .blob2 {
                top: 110px;
            }
        </style>
        <script>
            var first = -1;
            var second = -1;
            var fa = [], edus = [];
            var inputFile = '';
            function sendReq(id) {
                var index = parseInt(id.toString().substr(3));
                if (first === -1) {
                    first = index;
                    document.getElementById(id).setAttribute('style', 'background-color: green');
                    return;
                }
                if (index === 0) {
                    alert('ROOT can not be child!');
                    return;
                }
                if (index === first) {
                    alert('Parent node and child node can not be the same!');
                    return;
                }
                second = index;
                fa[second] = first;
                document.getElementById('edu' + first.toString()).setAttribute('style', 'background-color: white');
                $('#edu' + second.toString()).prop('disabled', true);
                $('#parent' + second.toString())[0].textContent = first.toString();
                var id1 = 'parent' + first.toString();
                var id2 = 'parent' + second.toString();
                drawCurve(id1, id2);
                first = -1; second = -1;
                updateProgress();
                return;
            };
            function updateProgress() {
                var total = fa.length - 1;
                if (total <= 0) return;
                var labeled = 0;
                for (var i = 1; i < fa.length; ++i) {
                    if (fa[i] >= 0) ++labeled;
                }
                var percent = labeled * 100 / total;
                var bar = document.getElementById('progress');
                bar.setAttribute('style', 'width: ' + percent.toString() + '%');
                return;
            }
            function saveToFile() {
                if (inputFile.length === 0) {
                    alert('Invalid input file!');
                    return;
                }
                var data = {'root': []};
                for (var i = 0; i < fa.length; ++i) {
                    var cur = {'parent': fa[i], 'text': edus[i]};
                    data['root'].push(cur);
                }
                var outFileName = inputFile + '.dep';
                var blob = new Blob([JSON.stringify(data)], outFileName);
                saveAs(blob, outFileName);
            }
        </script>
    </head>
    <body>
        <div class="picture">
        <canvas id="canvas" height="1500" width="1500"></canvas>
        <%
            for (int i = 0; i < 3; ++i) {
                out.println("<br>");
            }
        %>
        <div class="container blob1">
            <div class="col-lg-4 col-md-4 col-sm-4">
                <input type="file" id="files" name="files[]" multiple />
            </div>
        </div>

        <div class="container mybar">
              <div class="progress">
                <div id="progress" class="progress-bar" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" style="width: 0%">
                </div>
              </div>
        </div>

        <br>
        <div class="container blob2" id="list">
<!--            <div class="col-lg-10 col-md-10 col-sm-10" id="x">
                <button id="edu0" type="button" class="btn btn-default" style="background-color: grey">
                    <h5>This is a long sentence long sentence long sentence.</h5>
                </button>
            </div><br><br>
            <div class="col-lg-10 col-md-10 col-sm-10">
                <button id="edu1" type="button" class="btn btn-default" disabled>
                    <h5>This is a long sentence.</h5>
                </button>
            </div><br><br>
            <div class="col-lg-10 col-md-10 col-sm-10" id="z">
                <button id="edu2" type="button" class="btn btn-default" onclick="sendReq('edu2')">
                    <h5>This is a long sentence long sentence long sentence.This is a long sentence long sentence long sentence.</h5>
                </button>
            </div><br><br>-->
        </div></div>

        <script>
            function findPos(obj) {
                var curLeft = curTop = 0;
                if (obj.offsetParent) {
                    do {
                            curLeft += obj.offsetLeft;
                            curTop += obj.offsetTop;
                    } while (obj = obj.offsetParent);
                }
                return {x:curLeft, y:curTop};
            }
            function drawCurve(id1, id2) {
                var centerX = findPos(document.getElementById(id1));
                centerX.x += document.getElementById(id1).style.width;
                centerX.y += document.getElementById(id1).style.height;
                var centerZ = findPos(document.getElementById(id2));
                centerZ.x += document.getElementById(id2).style.width;
                centerZ.y += document.getElementById(id2).style.height;
                var canvasPos = findPos(document.getElementById('canvas'));
                centerX.x -= canvasPos.x;
                centerX.y -= canvasPos.y;
                centerZ.x -= canvasPos.x;
                centerZ.y -= canvasPos.y;
                centerX.y += 5; centerZ.y += 5;
                var ctx = document.getElementById('canvas').getContext('2d');
                ctx.strokeStyle = 'red';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(centerX.x, centerX.y);
                ctx.bezierCurveTo(0, centerX.y, 0, centerZ.y, centerZ.x, centerZ.y);
//              ctx.lineTo(centerZ.x, centerZ.y);
                ctx.stroke();

                ctx.beginPath();
                var radius = 8;
                ctx.fillStyle = 'red';
                ctx.moveTo(centerZ.x - radius, centerZ.y - radius);
                ctx.lineTo(centerZ.x - radius, centerZ.y + radius);
                ctx.lineTo(centerZ.x, centerZ.y);
                ctx.closePath();
                ctx.fill();
            }
            function handleFileSelect(evt) {
              var files = evt.target.files;
              inputFile = files[0];
              var reader = new FileReader();
              reader.onload = function(e) {
                  var contents = e.target.result.split('\n');
                  var res = '<div class="col-lg-12 col-md-12 col-sm-12">'
                               + '<span class="label label-info" id="parent0">null</span>'
                               + '<button id="edu0" onclick="sendReq(\'edu0\')"'
                               + ' type="button" class="btn btn-default" style="background-color: white">'
                               + '<h5>ROOT</h5>'
                               + '</button>'
                               + '</div><br><br><br>';
                  fa, edus = [], ['ROOT'];
                  fa.push(0);
                  var MAX_N = 150;
                  for (var i = 0; i < contents.length; i++) {
                      if (contents[i].length > MAX_N) {
                          contents[i] = contents[i].substr(0, MAX_N);
                      }
                      res += '<div class="col-lg-12 col-md-12 col-sm-12">'
                               + '<span class="label label-info" id="parent' + (i + 1).toString()
                               + '">null</span>'
                               + '<button id="edu' + (i + 1).toString()
                               + '" type="button" onclick="sendReq(\'edu' + (i + 1).toString() + '\')"'
                               + ' class="btn btn-default" style="background-color: white">'
                               + '<h5>' + contents[i] + '</h5>'
                               + '</button>'
                               + '</div><br><br><br>';
                       fa.push(-1);
                       edus.push(contents[i]);
                  }
                  $('#list').html(res);
              };
              reader.readAsText(inputFile);
              inputFile = inputFile.name;
            };
            document.getElementById('files').addEventListener('change', handleFileSelect, false);
        </script>

    </body>
</html>
