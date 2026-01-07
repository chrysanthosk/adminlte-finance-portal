import {
  Component,
  inject,
  ElementRef,
  ViewChild,
  AfterViewInit,
  OnDestroy,
  effect,
  computed
} from '@angular/core';
import { CommonModule, CurrencyPipe } from '@angular/common';
import { StoreService, IncomeEntry, ExpenseEntry } from '../../services/store.service';

declare const d3: any;

interface ChartData {
  date: string;
  inc: number;
  exp: number;
}

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, CurrencyPipe],
  template: `
    <div class="container-fluid">
      <!-- Info Boxes -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <!-- Income -->
        <div class="info-box bg-white dark:bg-gray-800 rounded shadow flex items-center p-3 border-t-2 border-green-500 transition-colors">
          <span class="info-box-icon bg-green-500 text-white rounded w-16 h-16 flex items-center justify-center text-2xl mr-4 shadow-sm">💰</span>
          <div class="info-box-content">
            <span class="info-box-text text-gray-500 dark:text-gray-400 text-sm uppercase font-bold">Today Income</span>
            <span class="info-box-number text-gray-800 dark:text-gray-100 text-xl font-bold">{{ store.todayIncome() | currency:'EUR' }}</span>
          </div>
        </div>

        <!-- MTD Income -->
        <div class="info-box bg-white dark:bg-gray-800 rounded shadow flex items-center p-3 border-t-2 border-blue-500 transition-colors">
          <span class="info-box-icon bg-blue-500 text-white rounded w-16 h-16 flex items-center justify-center text-2xl mr-4 shadow-sm">📅</span>
          <div class="info-box-content">
            <span class="info-box-text text-gray-500 dark:text-gray-400 text-sm uppercase font-bold">MTD Income</span>
            <span class="info-box-number text-gray-800 dark:text-gray-100 text-xl font-bold">{{ store.currentMonthStats().income | currency:'EUR' }}</span>
          </div>
        </div>

        <!-- MTD Expenses -->
        <div class="info-box bg-white dark:bg-gray-800 rounded shadow flex items-center p-3 border-t-2 border-red-500 transition-colors">
          <span class="info-box-icon bg-red-500 text-white rounded w-16 h-16 flex items-center justify-center text-2xl mr-4 shadow-sm">📉</span>
          <div class="info-box-content">
            <span class="info-box-text text-gray-500 dark:text-gray-400 text-sm uppercase font-bold">MTD Expenses</span>
            <span class="info-box-number text-gray-800 dark:text-gray-100 text-xl font-bold">{{ store.currentMonthStats().expenses | currency:'EUR' }}</span>
          </div>
        </div>

        <!-- Profit -->
        <div class="info-box bg-white dark:bg-gray-800 rounded shadow flex items-center p-3 border-t-2 border-yellow-500 transition-colors">
          <span class="info-box-icon bg-yellow-500 text-white rounded w-16 h-16 flex items-center justify-center text-2xl mr-4 shadow-sm">💹</span>
          <div class="info-box-content">
            <span class="info-box-text text-gray-500 dark:text-gray-400 text-sm uppercase font-bold">MTD Profit</span>
            <span class="info-box-number text-gray-800 dark:text-gray-100 text-xl font-bold"
              [class.text-red-600]="store.currentMonthStats().profit < 0"
              [class.text-green-600]="store.currentMonthStats().profit >= 0"
              [class.dark:text-red-400]="store.currentMonthStats().profit < 0"
              [class.dark:text-green-400]="store.currentMonthStats().profit >= 0">
              {{ store.currentMonthStats().profit | currency:'EUR' }}
            </span>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Main Chart -->
        <div class="card card-primary bg-white dark:bg-gray-800 rounded shadow border-t-4 border-blue-600 dark:border-blue-500 transition-colors">
          <div class="card-header flex justify-between items-center p-4 border-b dark:border-gray-700">
            <h3 class="card-title text-lg font-medium text-gray-700 dark:text-gray-200">Income vs Expenses (Last 30 Days)</h3>
          </div>
          <div class="card-body p-4">
            @if (hasData()) {
              <div #chartContainer class="w-full h-64"></div>
            } @else {
              <div class="w-full h-64 flex items-center justify-center text-gray-400">
                No data available for the last 30 days.
              </div>
            }
          </div>
        </div>

        <!-- Recent Income -->
        <div class="card card-success bg-white dark:bg-gray-800 rounded shadow border-t-4 border-green-600 dark:border-green-500 transition-colors">
          <div class="card-header flex justify-between items-center p-4 border-b dark:border-gray-700">
            <h3 class="card-title text-lg font-medium text-gray-700 dark:text-gray-200">Recent Income</h3>
          </div>
          <div class="card-body p-0">
            <div class="overflow-x-auto">
              <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
                <thead class="text-xs text-gray-700 dark:text-gray-300 uppercase bg-gray-50 dark:bg-gray-700">
                  <tr>
                    <th class="px-4 py-3">Date</th>
                    <th class="px-4 py-3 text-right">Total</th>
                    <th class="px-4 py-3">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  @for (entry of recentIncome(); track entry.id) {
                    <tr class="bg-white dark:bg-gray-800 border-b dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
                      <td class="px-4 py-3">{{ entry.date }}</td>
                      <td class="px-4 py-3 text-right font-medium text-green-600 dark:text-green-400">
                        {{ getIncomeTotal(entry) | currency:'EUR' }}
                      </td>
                      <td class="px-4 py-3 truncate max-w-xs">{{ entry.notes || '-' }}</td>
                    </tr>
                  } @empty {
                    <tr><td colspan="3" class="px-4 py-6 text-center">No recent income.</td></tr>
                  }
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

    </div>
  `
})
export class DashboardComponent implements AfterViewInit, OnDestroy {
  store = inject(StoreService);

  @ViewChild('chartContainer') chartContainer?: ElementRef;

  private resizeObserver?: ResizeObserver;

  recentIncome = computed(() => this.store.incomeEntries().slice(0, 5));

  hasData = computed(() => {
    // You still populate the last 30 days map in the chart,
    // but if there are zero entries overall, show "No data".
    return this.store.incomeEntries().length > 0 || this.store.expenseEntries().length > 0;
  });

  getIncomeTotal(entry: IncomeEntry) {
    return entry.lines.reduce((s: number, l: { amount: number }) => s + l.amount, 0);
  }

  constructor() {
    // Redraw when data changes (after login/loadAll)
    effect(() => {
      const inc = this.store.incomeEntries();
      const exp = this.store.expenseEntries();

      // Don’t draw until view is ready and there’s a container
      if (!this.chartContainer) return;

      // If there’s no data, chart container might not exist due to @if
      if (!this.hasData()) return;

      // Defer to avoid ExpressionChanged and to ensure DOM has size
      setTimeout(() => this.safeRenderChart(inc, exp), 0);
    });
  }

  ngAfterViewInit() {
    // Observe resize for responsive charts
    if (this.chartContainer?.nativeElement) {
      this.resizeObserver = new ResizeObserver(() => {
        if (this.hasData()) {
          this.safeRenderChart(this.store.incomeEntries(), this.store.expenseEntries());
        }
      });
      this.resizeObserver.observe(this.chartContainer.nativeElement);
    }

    if (this.hasData()) {
      this.safeRenderChart(this.store.incomeEntries(), this.store.expenseEntries());
    }
  }

  ngOnDestroy() {
    if (this.resizeObserver && this.chartContainer?.nativeElement) {
      this.resizeObserver.unobserve(this.chartContainer.nativeElement);
    }
    this.resizeObserver?.disconnect();
  }

  private safeRenderChart(income: IncomeEntry[], expenses: ExpenseEntry[]) {
    if (!this.chartContainer) return;
    if (typeof d3 === 'undefined') return;

    const el = this.chartContainer.nativeElement as HTMLElement;
    if (!el) return;

    // If not visible yet, wait.
    const w = el.clientWidth;
    const h = el.clientHeight;
    if (!w || !h) return;

    this.renderChart(income, expenses);
  }

  private renderChart(income: IncomeEntry[], expenses: ExpenseEntry[]) {
    const el = this.chartContainer!.nativeElement as HTMLElement;

    // Clear previous chart completely
    d3.select(el).selectAll('*').remove();

    const margin = { top: 20, right: 20, bottom: 30, left: 50 };
    const width = el.clientWidth - margin.left - margin.right;
    const height = el.clientHeight - margin.top - margin.bottom;

    const svg = d3.select(el)
      .append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
      .append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`);

    // Initialize Map with 0s for last 30 days
    const dailyData = new Map<string, { inc: number; exp: number }>();
    const now = new Date();

    for (let i = 29; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const k = d.toISOString().split('T')[0];
      dailyData.set(k, { inc: 0, exp: 0 });
    }

    // Populate actual data
    income.forEach((e: IncomeEntry) => {
      if (dailyData.has(e.date)) {
        dailyData.get(e.date)!.inc += e.lines.reduce((s: number, l: { amount: number }) => s + l.amount, 0);
      }
    });

    expenses.forEach((e: ExpenseEntry) => {
      if (dailyData.has(e.date)) {
        dailyData.get(e.date)!.exp += e.amount;
      }
    });

    const data: ChartData[] = Array.from(dailyData.entries()).map(([date, val]) => ({ date, ...val }));

    const x = d3.scaleBand()
      .range([0, width])
      .padding(0.1)
      .domain(data.map((d: ChartData) => d.date.substring(5))); // MM-DD labels

    const maxVal = d3.max(data, (d: ChartData) => Math.max(d.inc, d.exp)) || 100;
    const y = d3.scaleLinear()
      .range([height, 0])
      .domain([0, maxVal * 1.1]);

    const isDark = document.documentElement.classList.contains('dark');
    const axisColor = isDark ? '#9ca3af' : '#4b5563';

    const xAxis = d3.axisBottom(x)
      .tickValues(x.domain().filter((_: string, i: number) => i % 5 === 0));

    const gx = svg.append('g')
      .attr('transform', `translate(0,${height})`)
      .call(xAxis);

    const yAxis = d3.axisLeft(y).ticks(5);
    const gy = svg.append('g').call(yAxis);

    gx.selectAll('text').style('fill', axisColor);
    gx.selectAll('line').style('stroke', axisColor);
    gx.select('.domain').style('stroke', axisColor);

    gy.selectAll('text').style('fill', axisColor);
    gy.selectAll('line').style('stroke', axisColor);
    gy.select('.domain').style('stroke', axisColor);

    // Bars - Income
    svg.selectAll('.bar-inc')
      .data(data)
      .enter()
      .append('rect')
      .attr('class', 'bar-inc')
      .attr('x', (d: ChartData) => x(d.date.substring(5)))
      .attr('width', x.bandwidth() / 2)
      .attr('y', (d: ChartData) => y(d.inc))
      .attr('height', (d: ChartData) => height - y(d.inc))
      .attr('fill', '#22c55e');

    // Bars - Expense
    svg.selectAll('.bar-exp')
      .data(data)
      .enter()
      .append('rect')
      .attr('class', 'bar-exp')
      .attr('x', (d: ChartData) => x(d.date.substring(5))! + x.bandwidth() / 2)
      .attr('width', x.bandwidth() / 2)
      .attr('y', (d: ChartData) => y(d.exp))
      .attr('height', (d: ChartData) => height - y(d.exp))
      .attr('fill', '#ef4444');
  }
}