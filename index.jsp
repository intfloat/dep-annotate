<%--
    Document   : index.jsp
    Created on : 2015-10-6, 23:38:01
    Author     : Liang Wang
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title>Dependency Tree Annotate Tool</title>
        <script src="./js/jquery-1.11.3.min.js"></script>
        <script src="./js/bootstrap.min.js"></script>
        <script src="./js/jquery-ui.min.js"></script>
        <script src="./js/FileSaver.min.js"></script>
        <link href="./css/bootstrap.min.css" rel="stylesheet">
        <link href="./css/jquery-ui.min.css" rel="stylesheet">
        <link href="./css/jquery-ui.structure.min.css" rel="stylesheet">
        <link href="./css/jquery-ui.theme.min.css" rel="stylesheet">
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
            var MAX_N = 150;
            var fa = [], edus = [], operations = [], depRel = [];
            var inputFile = '', rel = '';
            var relations = ['attribution', 'background', 'cause',
                             'comparison', 'condition', 'contrast',
                             'elaboration', 'enablement', 'evaluation',
                             'explanation', 'joint', 'manner-means',
                             'summary', 'temporal', 'topic-change',
                             'topic-comment', 'same-unit', 'textual'];
            function sendReq(id) {
                var index = parseInt(id.toString().substr(3));
                if (first === -1) {
                    first = index;
                    document.getElementById(id).setAttribute('style', 'background-color: green');
                    var op = {'type': 'click', 'index': index};
                    operations.push(op);
                    for (var i = 0; i < fa.length; ++i) {
                        if (fa[i] >= 0 || i === first) {
                            $('#edu' + i.toString()).prop('disabled', true);
                        }
                    }
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
                popRelation();
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
                    var cur = {'parent': fa[i], 'text': edus[i], 'relation': depRel[i]};
                    data['root'].push(cur);
                }
                var outFileName = inputFile + '.dep';
                var blob = new Blob([JSON.stringify(data)], {type: "text/plain;charset=utf-8"});
                saveAs(blob, outFileName);
            }
            function undo() {
                if (inputFile.length === 0) {
                    alert('Invalid input file!');
                    return;
                }
                if (operations.length === 0) {
                    alert('Can not undo anymore!');
                    return;
                }
                var op = operations[operations.length - 1];
                if (op['type'] === 'click') {
                    recoverClickNode();
                }
                else if (op['type'] === 'connect') {
                    var id1 = op['id1'], id2 = op['id2'];
                    disconnect(id1, id2);
                }
                else if (op['type'] === 'delete') {
                    var id1 = op['id1'], id2 = op['id2'];
                    fa[id2] = id1;
                    depRel[id2] = op['relation'];
                    connect(id1, id2, 'red', depRel[id2]);
                }
                operations.splice(operations.length - 1, 1);
                updateProgress();
                return;
            }
            function recoverClickNode() {
                if (first < 0) {
                    alert('You are not supposed to see this...');
                    return;
                }
                document.getElementById('edu' + first.toString()).setAttribute('style', 'background-color: white');
                first = -1;
                for (var i = 0; i < fa.length; ++i) {
                   $('#edu' + i.toString()).prop('disabled', false);
                }
            }
            function connect(id1, id2, color, rel) {
                drawCurve('parent' + id1, 'parent' + id2, color);
                addRelation('parent' + id1, 'parent' + id2, rel);
                updateProgress();
            }
            function disconnect(id1, id2) {
                document.getElementById('parent' + id1).textContent = 'null';
                document.getElementById('parent' + id2).textContent = 'null';
                fa[parseInt(id2)] = -1; depRel[parseInt(id2)] = 'null';
                var ctx = document.getElementById('canvas').getContext('2d');
                var canvas = document.getElementById('canvas');
                ctx.clearRect(0, 0, canvas.width, canvas.height);
                for (var i = 0; i < fa.length; ++i) {
                    if (fa[i] >= 0) {
                        connect(fa[i], i, 'red', depRel[i]);
                    }
                }
                updateProgress();
            }
            // delete edge between selected EDU and its father
            function deleteEdge() {
                if (first < 0 || first >= fa.length) {
                    alert('ERROR: No node selected!');
                    return;
                }
                if (fa[first] < 0) {
                    alert('ERROR: No incoming edge for current node!');
                    return;
                }
                var id1 = fa[first], id2 = first;
                var op = {'type': 'delete', 'id1': id1, 'id2': id2, 'relation': depRel[id2]};
                recoverClickNode(first);
                disconnect(id1, id2);
                operations.push(op);
            }
        </script>
    </head>
    <body id="body">
        <div class="picture">
        <canvas id="canvas" height="4500" width="1500"></canvas>
        <%
            for (int i = 0; i < 3; ++i) {
                out.println("<br>");
            }
        %>
        <div class="container blob1">
            <div class="col-lg-2 col-md-2 col-sm-2">
                <input type="file" id="files" name="files[]" multiple />
            </div>
            <div class="col-lg-1 col-md-1 col-sm-1">
                <input type="button" class="btn btn-info" value="保存" onclick="saveToFile()" style="visibility:hidden">
            </div>
            <div class="col-lg-1 col-md-1 col-sm-1">
                <input type="button" class="btn btn-info" value="撤销" onclick="undo()" hidden="true" style="visibility:hidden">
            </div>
            <div class="col-lg-1 col-md-1 col-sm-1">
                <input type="button" class="btn btn-info" value="删除边" onclick="deleteEdge()" hidden="true" style="visibility:hidden">
            </div>
            <div class="col-lg-1 col-md-1 col-sm-1">
                <input type="button" class="btn btn-info" value="加标签" onclick="addLabel()" hidden="true" style="visibility:hidden">
            </div>
            <div class="col-lg-1 col-md-1 col-sm-1">
                <input type="button" class="btn btn-info" value="删标签" onclick="deleteLabel()" hidden="true" style="visibility:hidden">
            </div>
            <div class="col-lg-1 col-md-1 col-sm-1">
                <input type="file" id="relation-file" style="display: none" />
                <input type="button" class="btn btn-info" value="自定义标签"
                       id="fakeBrowse" onclick="HandleBrowseClick();" hidden="true" style="visibility:hidden"/>
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
        </div>
        <div id="dialog-form" title="Add a relation" hidden="true">
          <form>
                 <select class="form-control" id="select" name="select" >
                 </select>
          </form>
        </div>

        <div id="new-relation-dialog" title="Click to remove relations">
          <form>
                 <ul class="list-group" id="relation-list">
                </ul>
          </form>
        </div>
        <script>
            function HandleBrowseClick() {
                $('#relation-file').click();
            }
            function Handlechange(evt) {
                var file = evt.target.files[0];
                var reader = new FileReader();
                reader.onload = function (e) {
                    var contents = e.target.result.split('\n');
                    relations = [];
                    for (var i = 0; i < contents.length; ++i) {
                        var r = contents[i].trim();
                        if (r.length > 0 && relations.indexOf(r) < 0) {
                            relations.push(r);
                        }
                    }
                    alert('SUCCESSFULLY load ' + relations.length.toString() + ' relations.');
                };
                reader.readAsText(file);
            }
            function popRelation() {
              var dialog;
              function relationCallback() {
                  rel = $('#select')[0].options[select.selectedIndex].text;
                  dialog.dialog('close');
                  fa[second] = first;
                  document.getElementById('edu' + first.toString()).setAttribute('style', 'background-color: white');
                  for (var i = 0; i < fa.length; ++i) {
                      $('#edu' + i.toString()).prop('disabled', false);
                  }
                  $('#parent' + second.toString())[0].textContent = first.toString();
                  var id1 = 'parent' + first.toString();
                  var id2 = 'parent' + second.toString();
                  drawCurve(id1, id2, 'red');
                  addRelation(id1, id2, rel);
                  var op = {'type': 'connect', 'id1': first.toString(), 'id2': second.toString()};
                  operations.push(op);
                  depRel[second] = rel;
                  first = -1; second = -1;
                  updateProgress();
              }
              dialog = $( "#dialog-form" ).dialog({
                autoOpen: false,
                height: 200,
                width: 450,
                modal: true,
                buttons: {
                  "OK": relationCallback
                }
              });
              var res = '';
              for (var i = 0; i < relations.length; ++i) {
                  res += '<option>' + relations[i] + '</option>';
              }
              $('#select').html(res);
              rel = '';
              dialog.dialog("open");
            };
        </script>
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
            function getTrimNumber(s) {
                var i = s.length - 1;
                while (i >= 0 && s[i] >= '0' && s[i] <= '9') {
                    --i;
                }
                return parseInt(s.substr(i + 1));
            }
            function addRelation(id1, id2, relation) {
                if (relation.length === 0) {
                    alert('Invalid relation');
                    return;
                }
                id1;
                var centerZ = findPos(document.getElementById(id2));
                centerZ.x += document.getElementById(id2).style.width;
                centerZ.y += document.getElementById(id2).style.height;
                var canvasPos = findPos(document.getElementById('canvas'));
                centerZ.x -= canvasPos.x;
                centerZ.y -= canvasPos.y;
                centerZ.y += 15;
                var ctx = document.getElementById('canvas').getContext('2d');
                ctx.font = "10px Arial";
                ctx.fillStyle = 'blue';
                while (relation.length < 42) relation = ' ' + relation;
                ctx.fillText(relation, 0, centerZ.y);
            }
            function drawCurve(id1, id2, color) {
                while (operations.length > 0 && operations[operations.length - 1]['type'] === 'click') {
                    operations.splice(operations.length - 1, 1);
                }
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
                var width = findPos(document.getElementById(id1)).x;
                var percent = 1 - Math.abs(getTrimNumber(id1) - getTrimNumber(id2)) / (fa.length - 1);
                if (edus.length > 30 && percent > 0.5) {
                    percent = percent - 0.5;
                }
                var offX = width * percent;
                var ctx = document.getElementById('canvas').getContext('2d');
                ctx.strokeStyle = color;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(centerX.x, centerX.y);
                ctx.bezierCurveTo(offX, centerX.y, offX, centerZ.y, centerZ.x, centerZ.y);
                ctx.stroke();

                ctx.beginPath();
                var radius = 5;
                ctx.fillStyle = color;
                ctx.moveTo(centerZ.x - radius, centerZ.y - radius);
                ctx.lineTo(centerZ.x - radius, centerZ.y + radius);
                ctx.lineTo(centerZ.x, centerZ.y);
                ctx.closePath();
                ctx.fill();
            }
            function endsWith(str, suffix) {
                return str.indexOf(suffix, str.length - suffix.length) !== -1;
            }
            function updateCanvasHeight() {
                document.getElementById('canvas').height = edus.length / 80 * 4500 + 1500;
            }
            function loadJsonData(e) {
                var obj = JSON.parse(e.target.result);
                fa = []; edus = []; depRel = [];
                obj = obj['root'];
                for (var i = 0; i < obj.length; ++i) {
                    fa[i] = obj[i]['parent'];
                    edus[i] = obj[i]['text'];
                    depRel[i] = obj[i]['relation'];
                }
                var res = '';
                for (var i = 0; i < fa.length; ++i) {
                    var father = 'null';
                    if (fa[i] >= 0) father = fa[i].toString();
                    var displayText = edus[i];
                    if (displayText.length > MAX_N) {
                        displayText = displayText.substr(0, MAX_N);
                    }
                    res += '<div class="col-lg-12 col-md-12 col-sm-12">'
                             + '<span class="label label-info" id="parent' + i.toString()
                             + '">' + father + '</span>'
                             + '<button id="edu' + i.toString()
                             + '" type="button" onclick="sendReq(\'edu' + i.toString() + '\')"'
                             + ' class="btn btn-default" style="background-color: white">'
                             + '<h5>' + displayText + '</h5>'
                             + '</button>'
                             + '</div><br><br><br>';
                }
                updateCanvasHeight();
                $('#list').html(res);
                for (var i = 0; i < fa.length; ++i) {
                    if (fa[i] >= 0) {
                        drawCurve('parent' + fa[i].toString(), 'parent' + i.toString(), 'red');
                        addRelation('parent' + fa[i].toString(), 'parent' + i.toString(), depRel[i]);
                    }
                }
                updateProgress();
            }
            function loadRawData(e) {
                var contents = e.target.result.split('\n');
                var res = '<div class="col-lg-12 col-md-12 col-sm-12">'
                             + '<span class="label label-info" id="parent0">null</span>'
                             + '<button id="edu0" onclick="sendReq(\'edu0\')"'
                             + ' type="button" class="btn btn-default" style="background-color: white">'
                             + '<h6>ROOT</h6>'
                             + '</button>'
                             + '</div><br><br><br>';
                fa = [-1]; delRel = ['null'];
                edus = ['ROOT'];
                for (var i = contents.length - 1; i >= 0; --i) {
                    if (contents[i].length === 0) {
                        contents.splice(i, 1);
                    }
                }
                for (var i = 0; i < contents.length; i++) {
                    var displayText = contents[i];
                    if (displayText.length > MAX_N) {
                        displayText = displayText.substr(0, MAX_N);
                    }
                    res += '<div class="col-lg-12 col-md-12 col-sm-12">'
                             + '<span class="label label-info" id="parent' + (i + 1).toString()
                             + '">null</span>'
                             + '<button id="edu' + (i + 1).toString()
                             + '" type="button" onclick="sendReq(\'edu' + (i + 1).toString() + '\')"'
                             + ' class="btn btn-default" style="background-color: white">'
                             + '<h5>' + displayText + '</h5>'
                             + '</button>'
                             + '</div><br><br><br>';
                     fa.push(-1); depRel.push('null');
                     edus.push(contents[i]);
                }
                updateCanvasHeight();
                $('#list').html(res);
                updateProgress();
            }
            function handleFileSelect(evt) {
              var arr = $('.btn-info');
              for (var i = 0; i < arr.length; ++i) {
                  arr[i].style.visibility = "visible";
              }
              var files = evt.target.files;
              if (!files || !files[0]) { // user cancel selection
                  return;
              }
              inputFile = files[0];
              var reader = new FileReader();
              if (endsWith(inputFile.name, '.dep')) {
                  reader.onload = loadJsonData;
              }
              else {
                reader.onload = loadRawData;
              }
              reader.readAsText(inputFile);
              inputFile = inputFile.name;
              var ctx = document.getElementById('canvas').getContext('2d');
              var canvas = document.getElementById('canvas');
              ctx.clearRect(0, 0, canvas.width, canvas.height);
              operations = [];
              first = second = -1;
            };
            document.getElementById('files').addEventListener('change', handleFileSelect, false);
            document.getElementById('relation-file').addEventListener('change', Handlechange, false);

            function addLabel() {
                var label = prompt('New relation:');
                if (!label) {
                    return;
                }
                label = label.trim().toLowerCase();
                if (label.length === 0) {
                    alert('ERROR: Can not be empty');
                    return;
                }
                if (relations.indexOf(label) > 0) {
                    alert('ERROR: Relation ' + label + ' already exists.');
                    return;
                }
                relations.unshift(label);
                alert('SUCCESSFULLY added new relation ' + label);
            }

            function deleteLabel() {
                var nullCallback = function() { dialog.dialog('close'); };
                var dialog = $('#new-relation-dialog').dialog({
                    autoOpen: false,
                    height: 600,
                    width: 350,
                    modal: true,
                    buttons: {
                        'OK': nullCallback
                    }
                });
                var res = '';
                for (var i = 0; i < relations.length; ++i) {
                    res += '<li class="list-group-item">' + relations[i]
                            + '<img src="./css/images/remove.jpeg" style="width:20px;height:20px;" align="right"></li>';
                }
                $('#relation-list').html(res);
                $(".list-group-item").on("click", function(){
                    var r = this.textContent.trim();
                    $(this).remove();
                    var pos = relations.indexOf(r);
                    if (pos >= 0) {
                        relations.splice(pos, 1);
                    }
                });
                dialog.dialog('open');
            }
        </script>
    </body>
</html>
