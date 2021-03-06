var lastFiles;

function disableFileUpload() {
    document.getElementById('fileToUpload').setAttribute('disabled', 'disabled');
    return true;
}

function fileSelected() {
    var files = document.getElementById('fileToUpload').files;
    var totalSize = 0;
    for (i = 0; i < files.length; i++)
        totalSize += files[i].size;

    if (totalSize >= 1024 * 1024 * 100)
        alert('Total filesize should not exceed 100 MB');

    if (totalSize != 0) {
        if (totalSize > 1024 * 1024)
            totalSize = (Math.round(totalSize * 100 / (1024 * 1024)) / 100).toString() + 'MB';
        else
            totalSize = (Math.round(totalSize * 100 / 1024) / 100).toString() + 'KB';

        //document.getElementById('fileName').innerHTML = 'Name: ' + file.name;
        document.getElementById('fileSize').innerHTML = 'Size: ' + totalSize;
        //document.getElementById('fileType').innerHTML = 'Type: ' + file.type;
        document.getElementById('progressNumber').innerHTML = '';
        lastFiles = null;
    }
}

function uploadFile() {
    if (lastFiles === undefined) return; // no file selected
    if (lastFiles === null) {
        var fd = new FormData();
        var files = document.getElementById('fileToUpload').files;
        for (i = 0; i < files.length; i++) {
            var curFile = files[i];
            fd.append('fileToUpload' + i, files[i]);
        }
	fd.append('key', '96ec6a016064b7d915ea');
	fd.append('nameOnly', '1');

        var xhr = new XMLHttpRequest();
        xhr.upload.addEventListener('progress', uploadProgress, false);
        xhr.addEventListener('load', uploadComplete, false);
        xhr.addEventListener('error', uploadFailed, false);
        xhr.addEventListener('abort', uploadCanceled, false);
        xhr.open('POST', 'https://files.progarm.org/cgi-bin/upload.pl');
        xhr.send(fd);
    } else
        addFile(lastFiles);
}

function addFiles(filenames) {
    var el = document.getElementById('aftertext'); // comment
    if (el === null)
        el = document.getElementById('text'); // edit

    if (el != null) {
        el.value += '\n\n';
        var lines = filenames.split('\n');
        for (var i = 0; i < lines.length; i++)
            if (lines[i]) {
                if (lines[i].substring(0, 6) != 'Error:')
                    el.value += '[[File:' + lines[i] + ']]\n';
                else
                    alert(evt.target.responseText);
            }

        el.scrollTop = el.scrollHeight;
        el.focus();
    }
}

function uploadProgress(evt) {
    if (evt.lengthComputable) {
        var percentComplete = Math.round(evt.loaded * 100 / evt.total);
        document.getElementById('progressNumber').innerHTML = percentComplete.toString() + '%';
    } else
        document.getElementById('progressNumber').innerHTML = '...';
}

function uploadComplete(evt) {
    lastFiles = evt.target.responseText;
    document.getElementById('progressNumber').innerHTML = '100%';
    addFiles(evt.target.responseText);
    document.getElementById('fileToUpload').value = ''; // TODO do that on Save instead?
}

function uploadFailed(evt) {
    alert('There was an error attempting to upload the file.');
}

function uploadCanceled(evt) {
    alert('The upload has been canceled by the user or the browser dropped the connection.');
}
