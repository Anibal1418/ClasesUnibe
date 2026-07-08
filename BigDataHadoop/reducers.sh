set -e

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export HADOOP_HOME=/content/hadoop-3.5.0
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

STREAMING_JAR=$(ls $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar | head -n 1)

echo "reducers,tiempo_ms" > /content/tiempos_reducers.csv

for R in 1 2 4
do
  OUTPUT="/user/root/wordcount/output_r${R}"

  hdfs dfs -rm -r -f $OUTPUT || true

  INICIO=$(date +%s%3N)

  hadoop jar $STREAMING_JAR \
    -D mapreduce.job.reduces=$R \
    -files mapper.py,reducer.py \
    -mapper "python3 mapper.py" \
    -reducer "python3 reducer.py" \
    -input /user/root/wordcount/input \
    -output $OUTPUT > /dev/null 2>&1

  FIN=$(date +%s%3N)
  TIEMPO=$((FIN - INICIO))

  echo "${R},${TIEMPO}" >> /content/tiempos_reducers.csv
  echo "Reducers: $R | Tiempo: $TIEMPO ms"
done

echo ""
cat /content/tiempos_reducers.csv
