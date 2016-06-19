'use strict';

var app = angular.module('DepAnnotate', ['ngFileUpload', 'ngToast']);

app.constant('CONSTANTS', {
        relations: ['attribution', 'background', 'cause',
                        'comparison', 'condition', 'contrast',
                        'elaboration', 'enablement', 'evaluation',
                        'explanation', 'joint', 'manner-means',
                        'summary', 'temporal', 'topic-change',
                        'topic-comment', 'same-unit', 'textual'],
        blinkColor: '#00ffff',
        MAX_N: 150,
        CANVAS_WIDTH: 1500
});

app.filter('TransformParent', function() {
   return function(p) {
        return (p < 0) ? 'null' : p;
   };
});

app.filter('TailorString', ['CONSTANTS', function(CONSTANTS) {
   return function(s) {
       if (s.length > CONSTANTS.MAX_N) {
           s = s.substr(0, CONSTANTS.MAX_N);
       }
       return s;
   };
}]);

app.service('Utils', function() {
   return {
       findPos: function(obj) {
            var curLeft = 0, curTop = 0;
            if (obj.offsetParent) {
                do {
                    curLeft += obj.offsetLeft;
                    curTop += obj.offsetTop;
                    obj = obj.offsetParent;
                } while (obj);
            }
            return {x: curLeft, y: curTop};
        },
       getTrimNumber: function(s) {
            var i = s.length - 1;
            while (i >= 0 && s[i] >= '0' && s[i] <= '9') {
                --i;
            }
            return parseInt(s.substr(i + 1));
        },
       endsWith: function(str, suffix) {
            return str.indexOf(suffix, str.length - suffix.length) !== -1;
        }
    };
});

app.config(['ngToastProvider', function(ngToastProvider) {
    ngToastProvider.configure({
        horizontalPosition: 'center'
    });
}]);

app.controller('EDUListController',
                    ['$scope', 'Upload', 'CONSTANTS', 'Utils', 'ngToast',
                    function($scope, Upload, CONSTANTS, Utils, ngToast) {
    var second = -1;
    var rel = '';

    $scope.first = -1;
    $scope.inputFile = '';
    $scope.edus = [];
    $scope.fa = [];
    $scope.depRel = [];
    $scope.relations = CONSTANTS.relations;
    $scope.operations = [];
    $scope.blinkColor = CONSTANTS.blinkColor;
    $scope.canvas_height = 700;
    $scope.canvas_width = CONSTANTS.CANVAS_WIDTH;
    $scope.$watch('edus.length', function() {
        // empirical formula
        $scope.canvas_height = ($scope.edus.length === 0) ? 700 : ($scope.edus.length / 75 * 4500 + 100);
    });
    $scope.addLabel = function() {
        var label = prompt('New relation:').trim().toLowerCase();
        if (!label) {
            ngToast.danger({
                content: 'ERROR: label can not be empty',
                timeout: 2000
            });
            return;
        }
        if ($scope.relations.indexOf(label) > 0) {
            ngToast.danger({
                content: 'ERROR: Label ' + label + ' already exists.',
                timeout: 2000
            });
            return;
        }
        $scope.relations.unshift(label);
        ngToast.success({
           content: 'SUCCESSFULLY added new relation ' + label,
            timeout: 2000
        });
    };
    $scope.loadRawData = function(e) {
        var contents = e.target.result.split('\n');
        $scope.edus = ['ROOT'];
        var i;
        for (i = contents.length - 1; i >= 0; --i) {
            if (contents[i].length === 0) {
                contents.splice(i, 1);
            }
        }
        $scope.fa = _.range(contents.length + 1).map(function() { return -1; });
        $scope.depRel = _.range(contents.length + 1).map(function() { return 'null'; });
        for (i = 0; i < contents.length; i++) {
            $scope.edus.push(contents[i]);
        }
    };
    $scope.loadJsonData = function(e) {
        var obj = JSON.parse(e.target.result);
        var i;
        $scope.fa = [];
        $scope.depRel = [];
        $scope.edus = [];
        obj = obj.root;
        for (i = 0; i < obj.length; ++i) {
            $scope.fa[i] = obj[i].parent;
            $scope.edus[i] = obj[i].text;
            $scope.depRel[i] = obj[i].relation;
        }
        $scope.$apply();
        for (i = 0; i < $scope.fa.length; ++i) {
            if ($scope.fa[i] >= 0) {
                drawCurve('parent' + $scope.fa[i].toString(), 'parent' + i.toString(), 'red');
                addRelation('parent' + i.toString(), $scope.depRel[i]);
            }
        }
    };
    $scope.progress = 0;                    
    $scope.$watch('fa', function() {
        var total = $scope.fa.length - 1;
        if (total <= 0) return;
        var labeled = (_.filter($scope.fa.slice(1), function(e) { return e >= 0; })).length;
        $scope.progress = labeled * 100 / total;
    }, true);
                        
    $scope.handleFileSelect = function ($files) {
        if (!$files || !$files[0]) {
            return;
        }
        var canvas = angular.element('#canvas')[0];
        var ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, $scope.canvas_width, $scope.canvas_height);
        $scope.operations = [];
        $scope.first = second = -1;
        $scope.inputFile = $files[0];
        var reader = new FileReader();
        if (Utils.endsWith($scope.inputFile.name, '.dep')) {
            reader.onload = $scope.loadJsonData;
        }
        else {
            reader.onload = $scope.loadRawData;
        }
        reader.readAsText($scope.inputFile);
        $scope.inputFile = $scope.inputFile.name;
    };
    $scope.saveToFile = function() {
        var data = {root: []};
        for (var i = 0; i < $scope.fa.length; ++i) {
            var cur = {parent: $scope.fa[i], text: $scope.edus[i], relation: $scope.depRel[i]};
            data.root.push(cur);
        }
        var outFileName = $scope.inputFile + '.dep';
        var blob = new Blob([JSON.stringify(data, null, '\t')], {type: "text/plain;charset=utf-8"});
        saveAs(blob, outFileName);
    };
    $scope.undo = function() {
        var op = _.last($scope.operations);
        if (op.type === 'click') {
            $scope.first = -1;
        }
        else if (op.type === 'connect') {
            disconnect(op.id1, op.id2);
        }
        else if (op.type === 'delete') {
            var id1 = op.id1, id2 = op.id2;
            $scope.fa[id2] = id1;
            $scope.depRel[id2] = op.relation;
            connect(id1, id2, 'red', $scope.depRel[id2]);
        }
        $scope.operations.pop();
    };

    $scope.deleteEdge = function () {
        // delete edge between selected EDU and its father
        if ($scope.first < 0 || $scope.first >= $scope.fa.length) {
            ngToast.danger({
                content: 'ERROR: No node selected!',
                timeout: 2000
            });
            return;
        }
        if ($scope.fa[$scope.first] < 0) {
            ngToast.danger({
                content: 'ERROR: No incoming edge for current node!',
                timeout: 2000
            });
            return;
        }
        var id1 = $scope.fa[$scope.first], id2 = $scope.first;
        var op = {type: 'delete', id1: id1, id2: id2, relation: $scope.depRel[id2]};
        $scope.first = -1;
        disconnect(id1, id2);
        $scope.operations.push(op);
    };

    $scope.openDeleteDialog = false;
    $scope.deleteLabel = function() {
        var dialog = $('#new-relation-dialog').dialog({
            autoOpen: false,
            height: 600,
            width: 350,
            modal: true,
            buttons: {
                OK: function() {
                    $scope.openDeleteDialog = false;
                    $scope.$apply();
                    dialog.dialog('close');
                }
            }
        });
        $scope.openDeleteDialog = true;
        dialog.dialog('open');
    };

    $scope.removeRelation = function(relation) {
        var pos = $scope.relations.indexOf(relation);
        if (pos >= 0) {
            $scope.relations.splice(pos, 1);
            ngToast.info({
                content: 'Successfully removed relation ' + relation,
                timeout: 2000
            });
        }
    };

    $scope.mouseOverIndex = -1;
    $scope.mouseOverHandler = function(pos) {
        if (pos < 0 || pos >= $scope.fa.length || $scope.fa[pos] < 0) {
            return;
        }
        $scope.mouseOverIndex = pos;
        var canvas = angular.element('#canvas')[0];
        var ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, $scope.canvas_width, $scope.canvas_height);
        for (var i = 0; i < $scope.fa.length; ++i) {
            if (i === pos && $scope.fa[i] >= 0) {
                connect($scope.fa[i], i, CONSTANTS.blinkColor, $scope.depRel[i]);
            }
            else if ($scope.fa[i] >= 0) {
                connect($scope.fa[i], i, 'red', $scope.depRel[i]);
            }
        }
    };

    $scope.mouseOutHandler = function(pos) {
        if (pos < 0 || pos >= $scope.fa.length || $scope.fa[pos] < 0) {
            return;
        }
        $scope.mouseOverIndex = -1;
        var canvas = angular.element('#canvas')[0];
        var ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, $scope.canvas_width, $scope.canvas_height);
        _.each($scope.fa, function(v, i) {
            if (v >= 0) {
                connect(v, i, 'red', $scope.depRel[i]);
            }
        });
    };

    $scope.highLight = function(id) {
        var index = parseInt(id.toString().substr(3));
        if ($scope.first === -1) {
            $scope.first = index;
            $scope.mouseOutHandler(id);
            var op = {type: 'click', index: index};
            $scope.operations.push(op);
        }
        else {
            second = index;
            popRelation();
        }
    };

    $scope.showAddDialog = false;
    var popRelation = function() {
        var dialog;
        function relationCallback() {
            rel = angular.element('#select')[0].options[select.selectedIndex].text;
            $scope.fa[second] = $scope.first;
            var id1 = 'parent' + $scope.first.toString();
            var id2 = 'parent' + second.toString();
            drawCurve(id1, id2, 'red');
            addRelation(id2, rel);
            var op = {type: 'connect', id1: $scope.first.toString(), id2: second.toString()};
            $scope.operations.push(op);
            $scope.depRel[second] = rel;
            $scope.first = -1; second = -1;
            $scope.showAddDialog = false;
            dialog.dialog('close');
            $scope.$apply();
        }
        dialog = $("#dialog-form").dialog({
            autoOpen: false,
            height: 200,
            width: 450,
            modal: true,
            buttons: {
                OK: relationCallback
            }
        });
        rel = '';
        $scope.showAddDialog = true;
        dialog.dialog("open");
    };

    $scope.getParent = function(idx) {
        if ($scope.fa[idx] === -1) {
            return idx;
        }
        return $scope.getParent($scope.fa[idx]);
    };
    var drawCurve = function(id1, id2, color) {
        while ($scope.operations.length > 0 && _.last($scope.operations).type === 'click') {
            $scope.operations.splice($scope.operations.length - 1, 1);
        }
        var centerS = Utils.findPos(angular.element('#' + id1)[0]);
        centerS.x += angular.element('#' + id1)[0].style.width;
        centerS.y += angular.element('#' + id1)[0].style.height;
        var centerT = Utils.findPos(angular.element('#' + id2)[0]);
        centerT.x += angular.element('#' + id2)[0].style.width;
        centerT.y += angular.element('#' + id2)[0].style.height;
        var canvasPos = Utils.findPos(angular.element('canvas')[0]);
        centerS.x -= canvasPos.x;
        centerS.y -= canvasPos.y;
        centerT.x -= canvasPos.x;
        centerT.y -= canvasPos.y;
        centerS.y += 15;
        centerT.y += 5;
        var width = Utils.findPos(angular.element('#' + id1)[0]).x;
        var percent = 1 - Math.abs(Utils.getTrimNumber(id1) - Utils.getTrimNumber(id2)) / ($scope.fa.length - 1);
        if ($scope.edus.length > 30 && percent > 0.5) {
            percent = percent - 0.5;
        }
        percent = Math.min(percent, 0.85);
        var offX = width * percent;
        var ctx = angular.element('#canvas')[0].getContext('2d');
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(centerS.x, centerS.y);
        ctx.bezierCurveTo(offX, centerS.y, offX, centerT.y, centerT.x, centerT.y);
        ctx.stroke();

        ctx.beginPath();
        var radius = 6;
        ctx.fillStyle = color;
        ctx.moveTo(centerT.x - radius, centerT.y - radius);
        ctx.lineTo(centerT.x - radius, centerT.y + radius);
        ctx.lineTo(centerT.x, centerT.y);
        ctx.closePath();
        ctx.fill();
    };

    var connect = function(id1, id2, color, rel) {
        drawCurve('parent' + id1, 'parent' + id2, color);
        addRelation('parent' + id2, rel);
    };

    var disconnect = function(id1, id2) {
        $scope.fa[id2] = -1;
        $scope.depRel[id2] = 'null';
        var canvas = angular.element('#canvas')[0];
        var ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, $scope.canvas_width, $scope.canvas_height);
        for (var i = 0; i < $scope.fa.length; ++i) {
            if ($scope.fa[i] >= 0) {
                connect($scope.fa[i], i, 'red', $scope.depRel[i]);
            }
        }
    };

    $scope.handleBrowseClick = function() {
        var ctrl = angular.element('#relation-file');
        ctrl.on('change', handleChange);
        ctrl.click();
    };

    var handleChange = function(evt) {
        var file = evt.target.files[0];
        var reader = new FileReader();
        reader.onload = function(e) {
            var contents = e.target.result.split('\n');
            $scope.relations = [];
            for (var i = 0; i < contents.length; ++i) {
                var r = contents[i].trim();
                if (r.length > 0 && $scope.relations.indexOf(r) < 0) {
                    $scope.relations.push(r);
                }
            }
            ngToast.success({
               content: 'SUCCESSFULLY load ' + $scope.relations.length.toString() + ' relations.',
               timeout: 2000
            });
            $scope.$apply();
        };
        reader.readAsText(file);
    };

    var addRelation = function(id2, relation) {
        if (!relation) {
            ngToast.danger({
                content: 'Invalid relation',
                timeout: 2000
            });
            return;
        }
        var centerZ = Utils.findPos(angular.element('#' + id2)[0]);
        centerZ.x += angular.element('#' + id2)[0].style.width;
        centerZ.y += angular.element('#' + id2)[0].style.height;
        var canvasPos = Utils.findPos(angular.element('#canvas')[0]);
        centerZ.x -= canvasPos.x;
        centerZ.y -= canvasPos.y;
        centerZ.y += 15;
        var ctx = angular.element('#canvas')[0].getContext('2d');
        ctx.font = "10px Arial";
        ctx.fillStyle = 'blue';
        while (relation.length < 42) relation = ' ' + relation;
        ctx.fillText(relation, 0, centerZ.y);
    };

}]);