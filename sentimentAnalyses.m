%sets of positive and negative seed  words, seed words must appear at least
%ones otherwise they are ignored
seedsPositive = ["achieve" "advantage" "better" "creative" "efficiency" ...
    "efficiently" "enhance" "greater" "improved" "improving" ...
    "innovation" "innovations" "innovative" "opportunities" "profitable" ...
    "profitably" "strength" "strengthen" "strong" "success"]';

seedsNegative = ["adverse" "adversely" "against" "complaint" "concern" ...
    "damages" "default" "deficiencies" "disclosed" "failure" ...
    "fraud" "impairment" "litigation" "losses" "misleading" ...
    "omit" "restated" "restructuring" "termination" "weaknesses"]';

%preprocess the text with the
% preprocessText function
documents = preprocessText(textData);
%word embedding that models similarity
% between words using training data.
emb = trainWordEmbedding(documents,'Window',25,'MinCount',20);
%embedding nodes corresponding to words and edges weighted by similarity
numNeighbors = 8;
lexicon = emb.Vocabulary;
sequenceWord = word2vec(emb,lexicon);

[WordsNear,dist] = vec2word(emb,sequenceWord,numNeighbors);
sourceNodes = repelem(lexicon,numNeighbors);
targetNodes = reshape(WordsNear,1,[]);
%calculate edge weights
edgeWeights = reshape(dist,1,[]);
%graph connecting each word to its neighbor by similarity scores
Graphword = graph(sourceNodes,targetNodes,edgeWeights,lexicon);
%remove repeated edges
Graphword = simplify(Graphword);
%visualize the graph
word = "failure";
idx = findnode(Graphword,word);
nbrs = neighbors(Graphword,idx);
wordSubgraph = subgraph(Graphword,[idx; nbrs]);
figure
plot(wordSubgraph)
title("Words connected to """ + word + """")

%create an array of sentiment score for each word in the lexicon
sentScores = zeros([1 numel(lexicon)]);
%specify max path length
maxLengthPath = 4;
for depth = 1:maxLengthPath
    
    % Calculate polarity scores.
    PosPol = polarityScores(seedsPositive,lexicon,Graphword,depth);
    NegPol = polarityScores(seedsNegative,lexicon,Graphword,depth);
    
    % Account for difference in overall mass of positive and negative flow
    % in the graph.
    b = sum(PosPol) / sum(NegPol);
        
    % Calculate new sentiment scores.
    NewSentScore = PosPol - b * NegPol;
    NewSentScore = normalize(NewSentScore,'range',[-1,1]);
    
    % Add scores to sum.
    sentScores = sentScores + NewSentScore;
end

%Normalize the sentiment scores by the number of iterations
sentScores = sentScores / maxLengthPath;
%table including vocabulary and corresponding sentiment scores
Table = table;
Table.Token = lexicon';
Table.SentimentScore = sentScores';
%remove tokens with neutral sentiment
ent = 0.1;
idx = abs(Table.SentimentScore) < ent;
Table(idx,:) = [];
%view first rows of the table in descending order
Table = sortrows(Table,'SentimentScore','descend');
head(Table)
%word cloud for positive words 
figure
subplot(1,2,1);
idx = Table.SentimentScore > 0;
tblPositive = Table(idx,:);
wordcloud(tblPositive,'Token','SentimentScore')
title('Positive Words')
%word cloud for negative words
subplot(1,2,2);
idx = Table.SentimentScore < 0;
tblNegative = Table(idx,:);
tblNegative.SentimentScore = abs(tblNegative.SentimentScore);
wordcloud(tblNegative,'Token','SentimentScore')
title('Negative Words')
%export the table in a csv file
filename = "financeSentimentLexicon.csv";
writetable(Table,filename)
%string array containing text data and preprocess it
textDataNew = [
    "This assignment is much harder than the other i have."
    "I have an assignment to submit due to next week, but it is much easier than i expected."];
documentsNew = preprocessText(textDataNew);
%evaluate sentiment
compoundScores = vaderSentimentScores(documentsNew,'SentimentLexicon',Table)

function polarity = polarityScores(seeds,lexicon,diagramWord,depth)
% Remove seeds missing from lexicon
idx = ~ismember(seeds,lexicon);
seeds(idx) = [];

% Initialize scores.
vocabularySize = numel(lexicon);
scores = zeros(vocabularySize);
idx = ismember(lexicon,seeds);
scores(idx,idx) = eye(numel(seeds));

% Loop over seeds.
for i = 1:numel(seeds)
    
    % Initialize search space.
    seed = seeds(i);
    Seedidx = lexicon == seed;
    findPlace = find(Seedidx);
    
    % Search at different depths.
    for d = 1:depth
    
        % Loop over nodes in search space.
        numNodes = numel(findPlace);
        
        for k = 1:numNodes
            
            Newidx = findPlace(k);
            
            % Find neighbors and weights.
            nbrs = neighbors(diagramWord,Newidx);
            Weightsidx = findedge(diagramWord,Newidx,nbrs);
            weights = diagramWord.Edges.Weight(Weightsidx);
            % Loop over neighbors.
            for j = 1:numel(nbrs)  
                % Calculate scores.
                score = scores(Seedidx,nbrs(j));
                scoreNew = scores(Seedidx,Newidx);
                % Update score.
                scores(Seedidx,nbrs(j)) = max(score,scoreNew*weights(j));
            end
            % Appended nodes to search space for next depth iteration.
            findPlace = [findPlace nbrs'];
        end
    end
end
% Find seeds in vocabulary.
[~,idx] = ismember(seeds,lexicon);
% Sum scores connected to seeds.
polarity = sum(scores(idx,:));
end
