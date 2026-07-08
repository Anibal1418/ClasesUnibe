set -e

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export HADOOP_HOME=/content/hadoop-3.5.0
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

STREAMING_JAR=$(ls $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar | head -n 1)

echo "Streaming JAR encontrado:"
echo $STREAMING_JAR

echo "Eliminando output anterior..."
hdfs dfs -rm -r -f /user/root/wordcount/output || true

echo "Ejecutando Hadoop Streaming WordCount..."
hadoop jar $STREAMING_JAR \
  -D mapreduce.job.reduces=1 \
  -files mapper.py,reducer.py \
  -mapper "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input /user/root/wordcount/input \
  -output /user/root/wordcount/output

echo "Job terminado."
