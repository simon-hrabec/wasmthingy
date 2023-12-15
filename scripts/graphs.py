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

def print_histograms(data_arr, filename, histfrom, histto):
	coord_dict = {}
	xmax = 0
	ymax = 0
	for x, y, name, data in data_arr:
		xmax = max(xmax, x)
		ymax = max(ymax, y)
		coord_dict[(x, y)] = (name, data)

	plt.figure()
	plt.clf()
	fig, axs = plt.subplots(nrows=xmax+1, ncols=ymax+1, figsize=(6, 6), sharey=True)

	for x in range(xmax+1):
		for y in range(ymax+1):
			axs_idx = get_axs_indexed(axs, x, y, xmax, ymax)
			if (x, y) in coord_dict:
				(name, data) = coord_dict[(x, y)]
				axs_idx.hist(data, range=(histfrom,histto), bins=min(101, histto-histfrom+1))
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
	# print(np.array(data_arr).shape, np.array(labels).shape)
	plt.boxplot(data_arr, labels=labels, showfliers=False)
	plt.savefig(filename+'.pdf')
	pdf.savefig()
	plt.close()

latency_original_posix_prio = genfromtxt(data_dir+'/latency_original_posix_prio', delimiter=';')
latency_rewrite_no_prio = genfromtxt(data_dir+'/latency_rewrite_no_prio', delimiter=';')
latency_rewrite_posix_prio = genfromtxt(data_dir+'/latency_rewrite_posix_prio', delimiter=';')
latency_rewrite_chrt_prio = genfromtxt(data_dir+'/latency_rewrite_chrt_prio', delimiter=';')
latency_node = genfromtxt(data_dir+'/latency_node', delimiter=';')
latency_wasmtime = genfromtxt(data_dir+'/latency_wasmtime', delimiter=';')
latency_wamr = genfromtxt(data_dir+'/latency_wamr', delimiter=';')
latency_wasmer_cranelift = genfromtxt(data_dir+'/latency_wasmer_cranelift', delimiter=';')
latency_wasmer_llvm = genfromtxt(data_dir+'/latency_wasmer_llvm', delimiter=';')
latency_data = [latency_original_posix_prio, latency_rewrite_no_prio, latency_rewrite_posix_prio, latency_rewrite_chrt_prio, latency_node, latency_wasmtime, latency_wamr]

jitter_original_posix_prio = genfromtxt(data_dir+'/jitter_original_posix_prio', delimiter=';')
jitter_rewrite_no_prio = genfromtxt(data_dir+'/jitter_rewrite_no_prio', delimiter=';')
jitter_rewrite_posix_prio = genfromtxt(data_dir+'/jitter_rewrite_posix_prio', delimiter=';')
jitter_rewrite_chrt_prio = genfromtxt(data_dir+'/jitter_rewrite_chrt_prio', delimiter=';')
jitter_node = genfromtxt(data_dir+'/jitter_node', delimiter=';')
jitter_wasmtime = genfromtxt(data_dir+'/jitter_wasmtime', delimiter=';')
jitter_wamr = genfromtxt(data_dir+'/jitter_wamr', delimiter=';')
jitter_wasmer_cranelift = genfromtxt(data_dir+'/jitter_wasmer_cranelift', delimiter=';')
jitter_wasmer_llvm = genfromtxt(data_dir+'/jitter_wasmer_llvm', delimiter=';')
jitter_data = [jitter_original_posix_prio, jitter_rewrite_no_prio, jitter_rewrite_posix_prio, jitter_rewrite_chrt_prio, jitter_node, jitter_wasmtime, jitter_wamr]

latency_arr = [
	(0, 0, "Original", latency_original_posix_prio),
	(0, 1, "C++ no prio", latency_rewrite_no_prio),
	(0, 2, "C++ posix prio", latency_rewrite_posix_prio),
	(0, 3, "C++ chrt prio", latency_rewrite_chrt_prio),
	(1, 0, "node", latency_node),
	(1, 1, "wastime", latency_wasmtime),
	(1, 2, "WAMR", latency_wamr),
	# (2, 1, "wasmer cranelift", 2500, latency_wasmer_cranelift),
	# (2, 2, "wasmer llvm", 2500, latency_wasmer_llvm),
]

jitter_arr = [
	(0, 0, "Original", jitter_original_posix_prio),
	(0, 1, "C++ no prio", jitter_rewrite_no_prio),
	(0, 2, "C++ posix prio", jitter_rewrite_posix_prio),
	(0, 3, "C++ chrt prio", jitter_rewrite_chrt_prio),
	(1, 0, "node", jitter_node),
	(1, 1, "wastime", jitter_wasmtime),
	(1, 2, "WAMR", jitter_wamr),
	# (2, 1, "wasmer cranelift", 2500, jitter_wasmer_cranelift),
	# (2, 2, "wasmer llvm", 2500, jitter_wasmer_llvm),
]



print_histograms(latency_arr, 'graphs/latency_hist', 0, 100)
print_histograms(jitter_arr, 'graphs/jitter_hist', -20, 20)

# labels=['no_prio', 'with_prio_cpp', 'with_prio_posix', 'node', 'wasmtime', 'wamr', 'wasmer_cranelift', 'wasmer_llvm']
labels=['Original', 'C++ N', 'C++ P', 'C++ C', 'node', 'wasmtime', 'WAMR']
print_boxplots(latency_data, labels, 'graphs/latency_box')
print_boxplots(jitter_data, labels, 'graphs/jitter_box')

stats = [
	("Original", latency_original_posix_prio),
	("C++ no prio", latency_rewrite_no_prio),
	("C++ posix prio", latency_rewrite_posix_prio),
	("C++ chrt prio", latency_rewrite_chrt_prio),
	("node", latency_node),
	("wastime", latency_wasmtime),
	("WAMR", latency_wamr),
	("wasmer cranelift", latency_wasmer_cranelift),
	("wasmer llvm", latency_wasmer_llvm),
]

for stat in stats:
	print("{} & {:.2f} & {:.2f} & {:.2f} & {:.2f} \\\\ \\hline".format(stat[0], np.min(stat[1]), np.mean(stat[1]), np.max(stat[1]), np.std(stat[1])))
	# C++1 & 8.33 & 8.18 & 12.12 \\
	# print(stat)

pdf.close()
print('Graph generated: ' + output_pdf)