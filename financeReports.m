function textData = financeReports(year,qtr,NameValueArgs)
%%financeReports Download 10-K and 10-Q reports
% textData = financeReports(year,qtr) downloads 10-K and 10-Q
% reports for the specified year and quarter.
%
% textData = financeReports(year,qtr,'MaxNumReports',N) also specifies the
% maximum number of reports to return.

arguments
    year
    qtr
    NameValueArgs.MaxNumReports = inf;
end

maxNumReports = NameValueArgs.MaxNumReports;

% Specify web options.
options = weboptions('ContentType','text','Timeout',10);

fprintf('Downloading 10-K and 10-Q reports...\n')
tic

% Read data from "master.idx".
url = "https://www.sec.gov/Archives/edgar/full-index/" + year + ...
    "/QTR" + qtr + "/master.idx";
data = string(webread(url,options));
data = splitlines(data);

% Extract form URLs.
idx = contains(data,"10-K") | contains(data,"10-Q");
urls = extractBetween(data(idx),"edgar","txt","Boundaries","inclusive");
urls = "https://www.sec.gov/Archives/" + urls;

% Loop over URLs.
textData = "";

for i = 1:numel(urls)
    
    % Ignore malformed reports or timeouts.
    try
        % Read data from URL.
        code = string(webread(urls(i),options));
        
        % Extract <HTML> elements between <TEXT> tags.
        code = extractBetween(code,"<TEXT>","</TEXT>");
        code = strtrim(code);
        code(~startsWith(code,"<html",IgnoreCase=true)) = [];
        
        % Extract text data.
        textDataNew = strings(1,numel(code));
        for j = 1:numel(code)
            textDataNew(j) = extractHTMLText(code(j));
        end

        % Remove empty reports.
        idx = textDataNew == "";
        textDataNew(idx) = [];
        
        textData = [textData textDataNew];
    end
    
    % Stop when maxNumReports reached.
    if numel(textData) >= maxNumReports
        textData(maxNumReports+1:end) = [];
        break
    end
end

fprintf('Done.\n');
toc

% Erase any leftover HTML tags.
textData = eraseTags(textData);

end