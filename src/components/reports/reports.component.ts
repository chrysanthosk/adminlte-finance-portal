
import { Component, inject, ElementRef, ViewChild, AfterViewInit, effect } from '@angular/core';
import { CommonModule, CurrencyPipe } from '@angular/common';
import { StoreService, IncomeEntry, ExpenseEntry } from '../../services/store.service';

declare const d3: any;

@Component({
  selector: 'app-reports',
  standalone: true,
  imports: [CommonModule, CurrencyPipe],
  template: `
    <div class="space-y-6">
      <div class="card card-purple bg-white dark:bg-gray-800 rounded shadow border-t-4 border-purple-600 dark:border-purple-500 transition-colors">
        <div class="card-header p-4 border-b dark:border-gray-700 flex justify-between items-center">
          <h3 class="card-title text-lg font-medium dark:text-gray-100">Category Breakdown (Expenses)</h3>
        </div>
        <div class="card-body p-4 flex justify-center">
           <div #pieChart class="w-full max-w-md h-64"></div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="card bg-white dark:bg-gray-800 rounded shadow transition-colors">
          <div class="card-header p-4 border-b dark:border-gray-700">
             <h3 class="card-title font-medium dark:text-gray-100">Monthly Summary</h3>
          </div>
          <div class="card-body p-0">
            <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
              <thead class="text-xs text-gray-700 dark:text-gray-300 uppercase bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-4 py-3">Month</th>
                  <th class="px-4 py-3 text-right">Income</th>
                  <th class="px-4 py-3 text-right">Expenses</th>
                  <th class="px-4 py-3 text-right">Profit</th>
                </tr>
              </thead>
              <tbody>
                @for (row of monthlyData(); track row.month) {
                  <tr class="bg-white dark:bg-gray-800 border-b dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
                    <td class="px-4 py-3 font-medium dark:text-gray-100">{{ row.month }}</td>
                    <td class="px-4 py-3 text-right text-green-600 dark:text-green-400">{{ row.income | currency:'EUR' }}</td>
                    <td class="px-4 py-3 text-right text-red-600 dark:text-red-400">{{ row.expenses | currency:'EUR' }}</td>
                    <td class="px-4 py-3 text-right font-bold" [class.text-red-600]="row.profit < 0" [class.text-green-600]="row.profit >= 0" [class.dark:text-red-400]="row.profit < 0" [class.dark:text-green-400]="row.profit >= 0">
                      {{ row.profit | currency:'EUR' }}
                    </td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  `
})
export class ReportsComponent implements AfterViewInit {
  store = inject(StoreService);
  @ViewChild('pieChart') pieContainer!: ElementRef;

  constructor() {
    effect(() => {
      const exps = this.store.expenseEntries();
      if (this.pieContainer) {
        this.renderPie(exps);
      }
    });
  }

  ngAfterViewInit() {
    this.renderPie(this.store.expenseEntries());
  }

  get monthlyData() {
    return () => {
      const map = new Map<string, { income: number, expenses: number }>();
      
      this.store.incomeEntries().forEach((e: IncomeEntry) => {
        const m = e.date.substring(0, 7);
        if (!map.has(m)) map.set(m, { income: 0, expenses: 0 });
        map.get(m)!.income += e.lines.reduce((s: number, l: { amount: number }) => s + l.amount, 0);
      });

      this.store.expenseEntries().forEach((e: ExpenseEntry) => {
        const m = e.date.substring(0, 7);
        if (!map.has(m)) map.set(m, { income: 0, expenses: 0 });
        map.get(m)!.expenses += e.amount;
      });

      return Array.from(map.entries())
        .map(([month, val]) => ({ month, ...val, profit: val.income - val.expenses }))
        .sort((a, b) => b.month.localeCompare(a.month));
    };
  }

  renderPie(expenses: ExpenseEntry[]) {
    if (!this.pieContainer || typeof d3 === 'undefined') return;

    const el = this.pieContainer.nativeElement;
    d3.select(el).selectAll('*').remove();

    const dataMap = new Map<string, number>();
    expenses.forEach((e: ExpenseEntry) => {
      const catName = this.store.expenseCategories().find(c => c.id === e.categoryId)?.name || 'Unknown';
      dataMap.set(catName, (dataMap.get(catName) || 0) + e.amount);
    });

    const data = Array.from(dataMap.entries()).map(([name, value]) => ({ name, value }));
    const width = el.clientWidth;
    const height = el.clientHeight;
    const radius = Math.min(width, height) / 2;

    const svg = d3.select(el)
      .append('svg')
      .attr('width', width)
      .attr('height', height)
      .append('g')
      .attr('transform', `translate(${width / 2},${height / 2})`);

    const color = d3.scaleOrdinal()
      .domain(data.map(d => d.name))
      .range(d3.schemeSet2);

    const pie = d3.pie()
      .value((d: any) => d.value);

    const arc = d3.arc()
      .innerRadius(radius * 0.5) 
      .outerRadius(radius * 0.9);

    const arcs = svg.selectAll('arc')
      .data(pie(data))
      .enter()
      .append('g');

    arcs.append('path')
      .attr('d', arc)
      .attr('fill', (d: any) => color(d.data.name))
      .attr('stroke', document.documentElement.classList.contains('dark') ? '#1f2937' : 'white')
      .style('stroke-width', '2px');

    arcs.append('text')
      .attr('transform', (d: any) => `translate(${arc.centroid(d)})`)
      .attr('text-anchor', 'middle')
      .text((d: any) => d.data.value > 100 ? d.data.name : '') 
      .style('font-size', '10px')
      .style('fill', document.documentElement.classList.contains('dark') ? '#e5e7eb' : '#333');
  }
}