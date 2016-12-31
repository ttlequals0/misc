var dir = require('node-dir'); //npm install node-dir
var fs = require('fs');
var path = require('path')

//var pathf = '\\\\192.168.5.104\\PlexMedia\\Movies\\';
var pathf = '/mnt/plex_media/movies';
if ((process.env.USERNAME + '   ').substring(0,3) =='dab') {
    pathf = 'Movies\\';
}

function buildQuality(filename) {
    return (/1080/.test(filename) &&  /RE.?PACK/i.test(filename) ? 5 :
    (/1080/.test(filename) ?  4 :
    (/720/.test(filename) &&  /RE.?PACK/i.test(filename) ? 3 :
    (/720/.test(filename) ?  2 : 1)))
);
}


function buildKey(filename) {
    var yr = null;
    var yrpos = null;
    var key = (filename.replace(/\([^\)]*?(1080|720)\([^\)]*?\)/, '').split(/(720|1080)/)[0].replace(/(extended|extras|ac3|resistance|\d?play.?HD|dvd.?rip|re.?packed|re.?pack|re.?rip|uncensored|web.?rip|br.?rip|[hx]264|mp\d|av(c|i)|qcf|hdtv.?rip|tv.?rip|unrated|yify|hdtv|bluray|cam.?rip|bd.?rip|mkv|torrent)/ig, '') + ' ')
    .replace(/['"]/g, '')
    .replace(/[,!\(\)\[\]-]/g, ' ')
    .replace(/&/g, ' and ')
    .replace(/\.\./g, ' ')
    .replace(/[\s\.]+/g, ' ')
    .replace(/\sV\s/i, ' 5 ')
    .replace(/\sIV\s/i, ' 4 ')
    .replace(/\sIII\s/i, ' 3 ')
    .replace(/\sII\s/i, ' 2 ')
    .trim()
    .replace(/([^\d]+)([\d]+)/g, '$1  $2')
    .replace(/([\d]+)([^\d]+)/g, '$1  $2')
    .trim().toLowerCase()
    .replace(/(^|[^\d])(19\d\d|20\d\d)($|[^\d])/, function(x, p1, p2, p3, offset, string) {yr = p2; yrpos = offset + p1.length; return x;})
    .replace(/\spart\s/i, ' Pt ');

    if (yr) {
        key = key.slice(0, yrpos) + key.slice(yrpos + 4) + ' ' + yr;
    }
    
    key = key.replace(/([A-Z0-9]+)/g, ' $1').toLowerCase().replace(/[\s]+/g, ' ');
    
    return key;
}


dir.files(pathf, function(err, files) {
//dir.files('Movies\\', function(err, files) {
    if (err) throw err;
    // sort ascending
    files.sort();
    // sort descending
    files.reverse();


    var fls = [];

    files = files.filter(function (file) {
        var ext = path.extname(file);
        var filename = path.basename(file);
        
     
        var isgood = ('.mkv'  ===  ext || '.avi'  ===  ext || '.mp4'  ===  ext);// && (/(dvd.?rip|web.?rip|br.?rip|hdtv.?rip|tv.?rip|cam.?rip|bd.?rip)/i.test(filename) || /1080/.test(filename) || /720/.test(filename) || /[\.\s\(\[](19\d\d|20\d\d)(\]\s*\.|\)\s*\.|\s*\.)(mkv|avi|mp4)/.test(filename));

        if  (isgood) {
            var key = buildKey(filename);
            
            if (key.length > 4)
            {
                if (!fls[key])
                    fls[key] = [];
                
                fls[key].push({ path : file,  w : buildQuality(filename) } ); 
            } else {
                isgood = false;
            }
        }
        
        return isgood;
    });    


    //console.log(fls);
    
    files = [];

    for(var i in fls) {
        if (fls[i].length < 2) {
            delete fls[i];
        } else {
            fls[i].sort(function(x, y) { return y.w - x.w; });

            for(var j = 1;j<fls[i].length;j++) {
                files.push(fls[i][j]['path']);
                
                fs.appendFileSync('logfile.txt', fls[i][j]['path'] + '\r\n');
                fs.unlink(fls[i][j]['path']);
            }
        }
    }
    
    
    
    console.log(files);
    
});