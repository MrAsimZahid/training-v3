CALL apoc.schema.assert({},{},true);

MATCH (n) DETACH DELETE n;

CREATE CONSTRAINT UniqueMovieIDConstraint ON (m:Movie)
ASSERT m.id IS UNIQUE;

CREATE CONSTRAINT UniquePersonIDConstraint ON (p:Person)
ASSERT p.id IS UNIQUE;

LOAD CSV WITH HEADERS FROM
'https://data.neo4j.com/advanced-cypher/movies2.csv' AS row
WITH row.movieId as movieId,
     row.title as title,
     row.genres as genres,
     toInteger(row.releaseYear) as releaseYear,
     toFloat(row.avgVote) as avgVote,
     collect({id: row.personId, name:row.name, born: toInteger(row.birthYear), died: toInteger(row.deathYear),personType: row.personType, roles: split(coalesce(row.characters,""),':')}) as people
MERGE (m:Movie {id:movieId})
  ON CREATE SET m.title=title, m.avgVote=avgVote,
  m.releaseYear=releaseYear, m.genres=split(genres,":")
WITH *
UNWIND people as person
MERGE (p:Person {id: person.id})
  ON CREATE SET p.name = person.name, p.born = person.born, p.died = person.died
WITH  m, person, p
CALL apoc.do.when(person.personType = 'ACTOR',
"MERGE (p)-[:ACTED_IN {roles: person.roles}]->(m)
           ON CREATE SET p:Actor",
"MERGE (p)-[:DIRECTED]->(m)
    ON CREATE SET p:Director",
{m:m, p:p, person:person}) YIELD value AS value
RETURN count(*);  // cannot end query with APOC call

CREATE INDEX PersonNameIndex FOR (p:Person) ON (p.name);

CREATE INDEX MovieTitleIndex FOR (m:Movie) ON (m.title);

CREATE CONSTRAINT UniqueGenreNameConstraint ON (g:Genre) ASSERT g.name IS UNIQUE;
MATCH (m:Movie)
UNWIND m.genres as name
WITH DISTINCT name, m
MERGE (g:Genre {name:name})
WITH g, m
MERGE (g)<-[:IS_GENRE]-(m);

CALL db.index.fulltext.createNodeIndex(
'MovieTitleMixedCase',['Movie'], ['title'])
