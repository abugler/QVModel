import csv 

with open("QVVoting Is-Payoff-always-positive-table.csv") as file:
	readCSV = csv.reader(file, delimiter=',')
	for row in readCSV:
		if len(row) == 8 and row[7] != "payoff":
			if float(row[7]) < 0:
				print("false")
				quit()
	print("true")