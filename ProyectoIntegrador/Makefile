.PHONY: validate gpu-test cpu-benchmark package

validate:
	python scripts/validate_project.py
	python -m py_compile gpu-service/app.py spark-function/main.py spark-function/local_mock.py spark/jobs/hybrid_pipeline.py

gpu-test:
	$(MAKE) -C gpu-service test

cpu-benchmark:
	OMP_NUM_THREADS=1 python scripts/benchmark_cpu.py --library gpu-service/build/libnormalizer.so --sizes 10000,100000,1000000,5000000 --repetitions 7 --output metrics/cpu_omp_1_thread.json
	OMP_NUM_THREADS=4 python scripts/benchmark_cpu.py --library gpu-service/build/libnormalizer.so --sizes 10000,100000,1000000,5000000 --repetitions 7 --output metrics/cpu_omp_4_threads.json

package:
	cd .. && zip -r Proyecto_Hibrido_BigData_Serverless.zip Proyecto_Hibrido_BigData_Serverless -x '*/build/*' '*/__pycache__/*'
