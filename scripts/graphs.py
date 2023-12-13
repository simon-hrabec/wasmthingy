import matplotlib.pyplot as plt
import numpy as np
from numpy import genfromtxt
from matplotlib.backends.backend_pdf import PdfPages
import sys

data_dir = sys.argv[1]
output_pdf = sys.argv[2]

pdf = PdfPages(output_pdf)

def get_axs_indexed(axs, x, y, xmax, ymax):
	if (xmax == 0 and ymax == 0):
		return axs
	if (xmax == 0 or ymax == 0):
		return axs[x+y]
	else:
		return axs[x, y]

def print_histograms(data_arr, filename):
	coord_dict = {}
	xmax = 0
	ymax = 0
	for x, y, name, hist_width, data in data_arr:
		xmax = max(xmax, x)
		ymax = max(ymax, y)
		coord_dict[(x, y)] = (name, hist_width, data)

	plt.figure()
	plt.clf()
	fig, axs = plt.subplots(nrows=xmax+1, ncols=ymax+1, figsize=(6, 6), sharey=True)

	for x in range(xmax+1):
		for y in range(ymax+1):
			axs_idx = get_axs_indexed(axs, x, y, xmax, ymax)
			if (x, y) in coord_dict:
				(name, hist_width, data) = coord_dict[(x, y)]
				axs_idx.hist(data, range=(0,hist_width), bins=100)
				axs_idx.set_title(name)
			else:
				axs_idx.axis('off')

	fig.subplots_adjust(hspace=0.4)
	pdf.savefig()
	plt.savefig(filename+'.pdf')
	plt.close()

def print_boxplots(data_arr, labels, filename):
	plt.figure()
	plt.clf()
	plt.boxplot(data_arr, labels=labels)
	plt.savefig(filename+'.pdf')
	pdf.savefig()
	plt.close()

latency_no_prio = genfromtxt(data_dir+'/latency_no_prio', delimiter=';')
latency_with_prio_cpp = genfromtxt(data_dir+'/latency_with_prio_cpp', delimiter=';')
latency_with_prio_posix = genfromtxt(data_dir+'/latency_with_prio_posix', delimiter=';')
latency_node = genfromtxt(data_dir+'/latency_node', delimiter=';')
latency_wasmtime = genfromtxt(data_dir+'/latency_wasmtime', delimiter=';')
latency_wamr = genfromtxt(data_dir+'/latency_wamr', delimiter=';')
# latency_wasmer_singlepass = genfromtxt(data_dir+'/latency_wasmer_singlepass', delimiter=';')
latency_wasmer_cranelift = genfromtxt(data_dir+'/latency_wasmer_cranelift', delimiter=';')
latency_wasmer_llvm = genfromtxt(data_dir+'/latency_wasmer_llvm', delimiter=';')
# latency_data = [latency_no_prio, latency_with_prio_cpp, latency_with_prio_posix, latency_node, latency_wasmtime, latency_wamr, latency_wasmer_singlepass, latency_wasmer_cranelift, latency_wasmer_llvm]
latency_data = [latency_no_prio, latency_with_prio_cpp, latency_with_prio_posix, latency_node, latency_wasmtime, latency_wamr, latency_wasmer_cranelift, latency_wasmer_llvm]

jitter_no_prio = genfromtxt(data_dir+'/jitter_no_prio', delimiter=';')
jitter_with_prio_cpp = genfromtxt(data_dir+'/jitter_with_prio_cpp', delimiter=';')
jitter_with_prio_posix = genfromtxt(data_dir+'/jitter_with_prio_posix', delimiter=';')
jitter_node = genfromtxt(data_dir+'/jitter_node', delimiter=';')
jitter_wasmtime = genfromtxt(data_dir+'/jitter_wasmtime', delimiter=';')
jitter_wamr = genfromtxt(data_dir+'/jitter_wamr', delimiter=';')
jitter_wasmer_cranelift = genfromtxt(data_dir+'/jitter_wasmer_cranelift', delimiter=';')
jitter_wasmer_llvm = genfromtxt(data_dir+'/jitter_wasmer_llvm', delimiter=';')
jitter_data = [jitter_no_prio, jitter_with_prio_cpp, jitter_with_prio_posix, jitter_node, jitter_wasmtime, jitter_wamr, jitter_wasmer_cranelift, jitter_wasmer_llvm]

latency_arr = [
	(0, 0, "C++", 50, latency_no_prio),
	(0, 1, "C++ (prio/C++ sleep)", 50, latency_with_prio_cpp),
	(0, 2, "C++ (pri/POSIX sleep)", 50, latency_with_prio_posix),
	(1, 0, "node", 50, latency_node),
	(1, 1, "wastime", 50, latency_wasmtime),
	(1, 2, "wamr", 50, latency_wamr),
	(2, 1, "wasmer cranelift", 2500, latency_wasmer_cranelift),
	(2, 2, "wasmer llvm", 2500, latency_wasmer_llvm),
]

jitter_arr = [
	(0, 0, "C++", 50, jitter_no_prio),
	(0, 1, "C++ (prio/C++ sleep)", 50, jitter_with_prio_cpp),
	(0, 2, "C++ (pri/POSIX sleep)", 50, jitter_with_prio_posix),
	(1, 0, "node", 50, jitter_node),
	(1, 1, "wastime", 50, jitter_wasmtime),
	(1, 2, "wamr", 50, jitter_wamr),
	(2, 1, "wasmer cranelift", 2500, jitter_wasmer_cranelift),
	(2, 2, "wasmer llvm", 2500, jitter_wasmer_llvm),
]

labels=['no_prio', 'with_prio_cpp', 'with_prio_posix', 'node', 'wasmtime', 'wamr', 'wasmer_cranelift', 'wasmer_llvm']

print_histograms(latency_arr, 'graphs/latency_hist')
print_histograms(jitter_arr, 'graphs/jitter_hist')

print_boxplots(latency_data, labels, 'graphs/latency_box')
print_boxplots(jitter_data, labels, 'graphs/jitter_box')


stats = [
	("C++", np.std(latency_no_prio), np.mean(latency_no_prio)),
	("C++ (prio/C++ sleep)", np.std(latency_with_prio_cpp), np.mean(latency_with_prio_cpp)),
	("C++ (pri/POSIX sleep)", np.std(latency_with_prio_posix), np.mean(latency_with_prio_posix)),
	("node", np.std(latency_node), np.mean(latency_node)),
	("wastime", np.std(latency_wasmtime), np.mean(latency_wasmtime)),
	("wamr", np.std(latency_wamr), np.mean(latency_wamr)),
	("wasmer cranelift", np.std(latency_wasmer_cranelift), np.mean(latency_wasmer_cranelift)),
	("wasmer llvm", np.std(latency_wasmer_llvm), np.mean(latency_wasmer_llvm)),
]

for stat in stats:
	print(stat)

pdf.close()
print('Graph generated: ' + output_pdf)