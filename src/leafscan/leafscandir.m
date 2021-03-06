function leafscandir(lpath)
    %FIXME : validate path
    if ( exist(lpath) ~= 7 )
        error ( strcat('path ', lpath, 'is not a directory') );
    end

    % Put the csv file with all the results in leafscanresults.csv
    resultfile = fullfile(lpath, 'leafscanresults.csv' );
    [fd,syserrmsg]=fopen(resultfile,'wt');
    fprintf(fd, strcat( '# Result of leafscan of path', lpath) );
    fprintf(fd, strcat('#Columns: filename|PlantID|',...
                        'ExperimentName|Area(cm^2)|',...
                        'CircleCenter(x,y)|Radius') );

    filelist = dir(lpath);
    for ( i = 1:size(filelist, 1) )
        tmp = regexp(filelist(i).name, '.*\.[jpg|JPG|jpeg|JPEG]');
        if ( size(tmp, 1) == 0 )
            continue;
        end

        imgpath = fullfile(lpath, filelist(i).name);

        try
            [a, c, r] = leafscanimg(imgpath);
        catch err
            fprintf(fd, '%s|%s|%s:could not find leaf automatically\n', ...
                        filelist(i).name, ...
                        nameElems.pid{1}, ...
                        nameElems.exname{1} );
            continue;
        end


        nameElems = parseFilename( filelist(i).name, ...
                            '%s%s%s%s', ...
                            {'exname', 'cnum', 'cpos', 'pid'}, ...
                            '_');

        fprintf ( fd, '%s|%s|%s|%s|%s|%s|%s\n', ...
            filelist(i).name, ...
            char(nameElems.pid{1}), ...
            char(nameElems.exname{1}), ...
            a, c(1), c(2), r );

    end
    fclose(fd);
end

