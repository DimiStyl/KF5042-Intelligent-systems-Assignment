function documents = preprocessText(textData)
% Erase URLS.
textData = eraseURLs(textData);
% Tokenize.
documents = tokenizedDocument(textData);
% Remove tokens containing digits.
pat = textBoundary + wildcardPattern + digitsPattern + wildcardPattern + textBoundary;
documents = replace(documents,pat,"");
% Convert to lowercase.
documents = lower(documents);
% Remove short words.
documents = removeShortWords(documents,2);
% Remove stop words.
documents = removeStopWords(documents);
figure
wordcloud(documents);
end