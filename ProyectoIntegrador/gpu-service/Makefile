.PHONY: cpu-lib cuda-lib clean test

cpu-lib:
	mkdir -p build
	g++ -O3 -std=c++17 -fopenmp -fPIC -shared \
		src/normalizer_cpu.cpp -o build/libnormalizer.so

cuda-lib:
	mkdir -p build
	nvcc -O3 -std=c++17 -Xcompiler=-fopenmp -Xcompiler=-fPIC \
		-shared src/normalizer.cu -o build/libnormalizer.so

clean:
	rm -rf build

test: cpu-lib
	NORMALIZER_LIBRARY=build/libnormalizer.so pytest -q
