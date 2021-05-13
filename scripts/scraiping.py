import argparse
import bs4
import csv
import sys

def handle_args():
    parser = argparse.ArgumentParser(
        description='Parse Hyperledger Caliper report HTML')
    parser.add_argument('-a', '--header',
        action='store_true', help='print header')
    parser.add_argument('-f', '--file', required=True, help='input file')
    return parser.parse_args()

if __name__ == '__main__':
    args = handle_args()
    writer = csv.writer(sys.stdout)

    soup = bs4.BeautifulSoup(open(args.file), 'html.parser')
    tables = soup.find_all('table')
    records = tables[0].find_all('tr')

    data = {}
    header = records.pop(0)
    if args.header:
        items = [ th.get_text() for th in header.find_all('th') ]
        writer.writerow(items)
    for r in records:
        items = [ td.get_text() for td in r.find_all('td') ]
        test_name = items.pop(0)
        if test_name in data:
            data[test_name].extend(items)
        else:
            data[test_name] = [test_name]
            data[test_name].extend(items)
    for v in data.values():
        writer.writerow(v)
