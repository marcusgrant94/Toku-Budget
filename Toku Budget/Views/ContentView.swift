//
//  ContentView.swift
//  Toku Budget
//
//  Created by Marcus Grant on 8/16/25.
//

import SwiftUI
import CoreData

private enum Section: Hashable {
    case overview, transactions, subscriptions, budgets, bills /*, reports, settings */
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var scheme

    // We don’t actually need categories yet, but this lets us seed and use them later.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>

    @State private var selection: Section? = .overview
    @State private var rangeMode: DateRangeMode = .month   // ← Month / Quarter / Year

    private var window: DateWindow { DateWindow.make(for: rangeMode) }

    init() {} // ensure there’s no synthesized memberwise init

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Overview", systemImage: "rectangle.grid.2x2").tag(Section.overview)
                Label("Transactions", systemImage: "list.bullet.rectangle").tag(Section.transactions)
                Label("Subscriptions", systemImage: "square.stack.3d.up").tag(Section.subscriptions)
                Label("Bills", systemImage: "calendar.badge.clock").tag(Section.bills)
                Label("Budgets", systemImage: "chart.pie").tag(Section.budgets)
            }
            .listStyle(.sidebar)
            .navigationTitle("Toku Budget")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } detail: {
            ZStack {
                Theme.bg(scheme).ignoresSafeArea()
                switch selection {
                case .overview:
                    OverviewView(window: window, mode: rangeMode)              // ← uses selected window
                case .transactions:
                    TransactionsView(window: window)          // ← uses selected window
                case .subscriptions:
                    SubscriptionsView()
                case .bills:
                    BillsView()
                case .budgets:
                    BudgetView()
                case .none:
                    Text("Select a section")
                }
            }
        }
        .task { try? seedIfNeeded() }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                DateRangePicker(mode: $rangeMode)             // ← bound picker
                CurrencyChips()
                AppearancePicker()
                Spacer(minLength: 0)
            }

            #if os(macOS)
            // On-screen Import/Export menu
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Import CSV…") { ImportCoordinator.presentImporter(moc) }
                    Button("Export CSV…") { ExportCoordinator.presentExporter(moc) }
                } label: {
                    Label("Import/Export", systemImage: "arrow.up.arrow.down.square")
                }
            }
            #endif
        }
        .onChange(of: selection) { print("Sidebar selection ->", String(describing: $0)) }
    }

    // Dev-only seeding so UI has something to show
    private func seedIfNeeded() throws {
        if categories.isEmpty {
            ["Groceries","Transport","Entertainment","Utilities","Rent","Health","Shopping","Other"]
                .forEach { name in
                    let c = Category(context: moc)
                    c.name = name
                    c.icon = "tag"
                    c.colorHex = "#6B7280"
                }
            try moc.save()
        }
    }
}

// MARK: - Toolbar bits

struct DateRangePicker: View {
    @Binding var mode: DateRangeMode
    var body: some View {
        Picker("", selection: $mode) {
            ForEach(DateRangeMode.allCases) { m in
                Text(m.label).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 260)
    }
}

struct CurrencyChips: View {
    @State private var currency = "USD"
    var body: some View {
        HStack(spacing: 8) {
            Chip(title: "USD", selected: currency == "USD") { currency = "USD" }
            Chip(title: "JPY", selected: currency == "JPY") { currency = "JPY" }
        }
    }
}

struct Chip: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(selected ? Color.accentColor.opacity(0.12)
                                     : Theme.card(scheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cardBorder(scheme))
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date range model

enum DateRangeMode: Int, CaseIterable, Identifiable {
    case month = 0, quarter = 1, year = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .month:   return "Month"
        case .quarter: return "Quarter"
        case .year:    return "Year"
        }
    }
}

struct DateWindow: Equatable {
    let start: Date
    let end: Date

    static func make(for mode: DateRangeMode,
                     anchor: Date = Date(),
                     cal: Calendar = .current) -> DateWindow {
        switch mode {
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
            let end   = cal.date(byAdding: .month, value: 1, to: start)!
            return .init(start: start, end: end)

        case .quarter:
            let comps = cal.dateComponents([.year, .month], from: anchor)
            let month = comps.month ?? 1
            // Q1: Jan, Q2: Apr, Q3: Jul, Q4: Oct
            let qStartMonth = [1,4,7,10].last(where: { $0 <= month }) ?? 1
            var s = DateComponents()
            s.year  = comps.year
            s.month = qStartMonth
            let start = cal.date(from: s)!
            let end   = cal.date(byAdding: .month, value: 3, to: start)!
            return .init(start: start, end: end)

        case .year:
            let comps = cal.dateComponents([.year], from: anchor)
            let start = cal.date(from: comps)!                       // Jan 1
            let end   = cal.date(byAdding: .year, value: 1, to: start)! // next Jan 1
            return .init(start: start, end: end)
        }
    }
}




// MARK: - Preview

//#Preview {
//    let preview = PersistenceController(inMemory: true)
//    return ContentView()
//        .environment(\.managedObjectContext, preview.container.viewContext)
//}

