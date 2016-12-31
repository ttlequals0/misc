var dir = require('node-dir'); //npm install node-dir
var fs = require('fs');
var path = require('path')


//var pathf = '\\\\192.168.5.104\\PlexMedia\\TV Shows\\';
var pathf = '/mnt/plex_media/tv';
if ((process.env.USERNAME + '   ').substring(0,3) =='dab') {
    pathf = 'TV Shows\\';
}

dir.files(pathf, function(err, files) {
    if (err) throw err;
    // sort ascending
    files.sort();
    // sort descending
    files.reverse();


    var fls = [];
    var fre = /^(.*)?[\._]s0?(\d+)e0?(\d+)[\._]/i;
    files = files.filter(function (file) {
        var ext = path.extname(file);
        var filename = path.basename(file);
        
     
        var isgood = ('.mkv'  ===  ext || '.avi'  ===  ext || '.mp4'  ===  ext) && fre.test(filename);

        if  (isgood) {
            var m = filename.match(fre);
            var key = (m[1].replace('_', '.') + '_s' + m[2] + 'e' + m[3]).toLowerCase();
            
            if (!fls[key])
		fls[key] = [];
            
            fls[key].push({ path : file,  w : (/1080/.test(filename) &&  /RE.?PACKED/i.test(filename) ? 5 :
						 (/1080/.test(filename) ?  4 : 
                                                     (/720/.test(filename) &&  /RE.?PACKED/i.test(filename) ? 3 :
						         (/720/.test(filename) ?  2 : 1)      
                                                     )
                                                 )
                                              )} ); 
        }
        
        return isgood;
    });    

    //console.log(files); 
   
    files = [];

    for(var i in fls) {
        if (fls[i].length < 2) {
            delete fls[i];
        } else {
            fls[i].sort(function(x, y) { return y.w - x.w; });

            for(var j = 1;j<fls[i].length;j++) {
                files.push(fls[i][j]['path']);
                
                fs.appendFileSync('logfile.txt', fls[i][j]['path'] + '\r\n');

                //fs.unlink(fls[i][j]['path']);
            }
        }
    }
    
    
    
    console.log(files);
    
});