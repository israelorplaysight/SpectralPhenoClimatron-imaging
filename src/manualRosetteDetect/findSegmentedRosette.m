% Copyright (C) 2014 Joel Granados <joel.granados@gmail.com>
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
function [subimg, imgRange] = findSegmentedRosette ( lh, img )
    % rosette center
    rc = double(round(lh));

    % true when we are satified with the mask
    foundRosette = false;

    % Our square can grow as big as the nearest image edge.
    maxGrowth = min( [ rc(1)-1 rc(2)-1 ...
                      abs(size(img,2)-rc(1)) ...
                      abs(size(img,1)-rc(2)) ] );
    maxGrowth = maxGrowth - mod(maxGrowth,5); % Next multiple of 5 down.
    if ( maxGrowth > 200 ) % Only look at part of the image
        maxGrowth = 200;
    elseif ( maxGrowth < 5 )
        err = MException( 'findSegmentedRosette:InvalidMaxGrowth', ...
                          'maxGrowth var was calculated to be less than 5' );
        throw(err);
    end

    for ( i = 5:5:maxGrowth )
        % get a subimg
        imgRange = struct ( 'yFrom', rc(2)-i, 'yTo', rc(2)+i, ...
                            'xFrom', rc(1)-i, 'xTo', rc(1)+i );
        subimg = img( rc(2)-i:rc(2)+i , rc(1)-i:rc(1)+i , : );

        subimg = getKMeansMask ( subimg, [0 1], 0.01, 10 );

        % Uses morphological close to remove small noise responses.  Struct
        % element is a disk. Will bring close connected components together.
        se = strel('disk', 3);
        subimg = imclose(subimg, se);

        % Checks the sides of subimg for pixels greater than 0. We stop if no
        % edge pixel is greater than 0;
        if ( ( sum(subimg(:,1)) + sum(subimg(1,:))...
               + sum(subimg(size(subimg,1),:)) ...
               + sum(subimg(:,size(subimg,2))) ) == 0 )
            foundRosette = true;
            break;
        end
    end

    if ( ~foundRosette )
        % Means that we did not find rosette.
        err = MException( 'findSegmentedRosette:RosetteNotFound', ...
                          'Could not find a good separation');
        throw(err);
    end

    % Minimize mask to snuggly enclose connected components. 1 pixel margin.
    cc = bwconncomp(subimg, 4);
    pixList = regionprops(cc, 'PixelList');
    pl = vertcat(pixList.PixelList);
    yFrom = min(min(pl(:,2))) - 1;
    yTo = max(max(pl(:,2))) + 1;
    xFrom = min(min(pl(:,1))) - 1;
    xTo = max(max(pl(:,1))) + 1;
    subimg = subimg ( yFrom:yTo, xFrom:xTo );
    %imgOffset = [ imgOffset(1) + yFrom - 1  imgOffset(2) + xFrom - 1 ];
    imgRange = struct ( 'yFrom', imgRange.yFrom + yFrom - 1, ...
                        'yTo', imgRange.yFrom + yTo - 1, ...
                        'xFrom', imgRange.xFrom + xFrom - 1, ...
                        'xTo', imgRange.xFrom + xTo - 1);
end

% Classification with k=2.
%
% Important assumptions:
% Here we assume that individual plants make most part of the kimg. This will
% ensure that one of the means that k-means find is part of the plant green.
%
% Arguments:
% kimg is a 3D matrix (rgb image).
% M is the starting means. [0 1] should be ok.
% convRatio is the convergence ratio. 0.01 should be ok.
% maxIter are the maximum number of iterations. 10 should be ok.
%
% Steps:
% 1. Convert To Excess Green
% 2. Separate pixels into two classes.
% 3. Return mask
function retMask = getKMeansMask ( kimg, M, convRatio, maxIter )

    % 1. Convert To Excess Green
    kimg = double(kimg);
    kimg = kimg(:,:,2)*2 - kimg(:,:,1) - kimg(:,:,3);

    % normalize subimg. Range will be [0,1]
    kimg = kimg + abs(min(min(kimg)));
    kimg = kimg/max(max(kimg));

    % 2. Separate pixels into two classes.
    imgvec = reshape(kimg, 1, size(kimg,1)*size(kimg,2));
    retMask = getKMeansVecMask ( imgvec, M, convRatio, maxIter );

    % 3. Return mask
    retMask = reshape ( retMask, size(kimg,1), size(kimg,2) );

    % Steps:
    % 1. Create two groups: a)closest to M(1) and b) closest to M(2)
    % 2. Calculate mean of each group.
    % 3. End if change in mean is very small.
    % 4. Return mask of the bigger mean.
    function retVal = getKMeansVecMask ( vec, M, convRatio, maxIter )
        % keep track of the previous means.
        Mprev = M;

        % keep track of the nearness vectors.
        near21 = []; %pixels near to M(1)
        near22 = []; %pixels near to M(2)

        for ( i = 1:maxIter )
            % 1. Create two groups: a)closest to M(1) and b) closest to M(2)
            near21 = abs(vec - M(1)) < abs(vec - M(2));
            near22 = ~near21;

            % 2. Calculate mean of each group.
            M(1) = sum( vec( near21 ) ) / sum(near21);
            M(2) = sum( vec( near22 ) ) / sum(near22);

            % 3. End if change in mean is very small.
            if ( pdist([Mprev(1) Mprev(2): M(1) M(2)]) < convRatio )
                break;
            end

            Mprev = M;
        end

        % 4. Return mask of the bigger mean.
        retVal = near22;
        if ( M(1) > M(2) )
            retVal = near21;
        end
    end
end
