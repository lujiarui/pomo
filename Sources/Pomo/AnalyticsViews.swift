import Charts
import SwiftUI

private enum AllocationChartStyle: String, CaseIterable, Identifiable {
    case pie = "Pie"
    case bars = "Bars"
    var id: String { rawValue }
}

struct DailyAllocationView: View {
    @ObservedObject var store: TimerStore
    @State private var selectedDate = Date()
    @State private var grouping: AllocationGrouping = .category
    @State private var chartStyle: AllocationChartStyle = .pie

    private var activities: [DailyActivity] { store.activities(on: selectedDate) }
    private var allocations: [TimeAllocation] { SessionAnalytics.allocations(activities, by: grouping) }
    private var total: Int { allocations.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time allocation").font(.headline)
                    Text("See how your recorded focus time is shared across types and tasks.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DayPicker(date: $selectedDate)
                HStack(spacing: 20) {
                    Picker("Group by", selection: $grouping) {
                        ForEach(AllocationGrouping.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Chart", selection: $chartStyle) {
                        ForEach(AllocationChartStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if allocations.isEmpty {
                    AnalyticsEmptyState(symbol: "chart.pie", title: "No focus time on this day",
                                        detail: "Start a block with a task and optional type. Your time appears here as you work.")
                } else {
                    allocationChart
                    allocationLegend
                    if activities.contains(where: \.isCurrent) {
                        Label("Includes your current focus block", systemImage: "record.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if activities.contains(where: \.isEstimated) {
                        Text("Older sessions are split across days using estimated timing.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var allocationChart: some View {
        if chartStyle == .pie {
            ZStack {
                ForEach(Array(allocations.enumerated()), id: \.element.id) { index, item in
                    let start = Double(allocations.prefix(index).reduce(0) { $0 + $1.seconds }) / Double(max(1, total))
                    let end = start + Double(item.seconds) / Double(max(1, total))
                    AllocationSector(start: start, end: end)
                        .fill(color(item.name))
                        .accessibilityLabel(item.name)
                        .accessibilityValue("\(item.seconds.compactDuration), \(percentage(item.seconds))")
                }
            }
            .frame(height: 230)
            .overlay {
                VStack(spacing: 5) {
                    Text(total.compactDuration)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("FOCUS TIME").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        } else {
            Chart(allocations) { item in
                BarMark(x: .value("Minutes", Double(item.seconds) / 60), y: .value(grouping.rawValue, item.name))
                    .foregroundStyle(color(item.name))
                    .cornerRadius(4)
                    .accessibilityLabel(item.name)
                    .accessibilityValue("\(item.seconds.compactDuration), \(percentage(item.seconds))")
            }
            .chartYScale(domain: allocations.map(\.name))
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) {
                            Text(name).lineLimit(1).truncationMode(.tail).frame(maxWidth: 105, alignment: .trailing)
                        }
                    }
                }
            }
            .chartXAxisLabel("Minutes")
            .frame(height: max(170, CGFloat(allocations.count) * 34))
        }
    }

    private var allocationLegend: some View {
        VStack(spacing: 12) {
            ForEach(allocations) { item in
                HStack(spacing: 10) {
                    Circle().fill(color(item.name)).frame(width: 9, height: 9)
                    Text(item.name).font(.callout).lineLimit(2).textSelection(.enabled)
                    Spacer(minLength: 12)
                    Text(item.seconds.compactDuration).font(.callout.monospacedDigit())
                    Text(percentage(item.seconds))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
    }

    private func percentage(_ seconds: Int) -> String {
        (Double(seconds) / Double(max(1, total))).formatted(.percent.precision(.fractionLength(1)))
    }

    private func color(_ name: String) -> Color {
        let index = allocations.map(\.name).sorted().firstIndex(of: name) ?? 0
        return grouping == .category ? store.categoryColor(name) : ActivityColors.allocation(name, grouping: grouping, index: index)
    }
}

struct DailyTimelineView: View {
    @ObservedObject var store: TimerStore
    @State private var selectedDate = Date()

    private var activities: [DailyActivity] { store.activities(on: selectedDate) }
    private var total: Int { activities.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader("Timeline", detail: "A daily view of when you worked and what you worked on.")
                DayPicker(date: $selectedDate)
                if activities.isEmpty {
                    Card {
                        AnalyticsEmptyState(symbol: "clock", title: "No focus time on this day",
                                            detail: "Choose another date or start a focus block to build your timeline.")
                    }
                } else {
                    HStack {
                        Text(total.compactDuration).font(.title2.weight(.semibold)).monospacedDigit()
                        Text("focused · \(Set(activities.map(\.sessionID)).count) blocks")
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer()
                    }
                    timelineChart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("In time order").font(.headline)
                        ForEach(activities) { activity in
                            TimelineActivityRow(activity: activity, color: store.categoryColor(activity.category))
                        }
                    }
                    if activities.contains(where: \.isEstimated) {
                        Text("Estimated timing: older sessions did not record pauses. Their start and end span is shown, with the original focused duration preserved.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 34)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var timelineChart: some View {
        let day = Calendar.current.dateInterval(of: .day, for: selectedDate)!
        let tasks = activities.reduce(into: [String]()) { result, activity in
            if !result.contains(activity.task) { result.append(activity.task) }
        }
        let categories = Array(Set(activities.map(\.category))).sorted()
        return Card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Day at a glance").font(.headline)
                Chart(activities) { activity in
                    BarMark(
                        xStart: .value("Start", activity.startedAt),
                        xEnd: .value("End", activity.endedAt),
                        y: .value("Task", activity.task)
                    )
                    .foregroundStyle(by: .value("Type", activity.category))
                    .cornerRadius(3)
                    .opacity(activity.isEstimated ? 0.55 : 1)
                    .accessibilityLabel("\(activity.task), \(activity.category)")
                    .accessibilityValue("\(activity.startedAt.formatted(date: .omitted, time: .shortened)) to \(activity.endedAt.formatted(date: .omitted, time: .shortened)), \(activity.seconds.compactDuration)")
                }
                .chartForegroundStyleScale(domain: categories, range: categories.map { store.categoryColor($0) })
                .chartXScale(domain: day.start...day.end)
                .chartYScale(domain: tasks)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let task = value.as(String.self) {
                                Text(task).lineLimit(1).truncationMode(.tail).frame(maxWidth: 105, alignment: .trailing)
                            }
                        }
                    }
                }
                .frame(height: max(160, CGFloat(tasks.count) * 38 + 50))
                Text("Colors show types. Gaps are pauses, breaks, or untracked time.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct TimelineActivityRow: View {
    let activity: DailyActivity
    let color: Color

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(activity.task).font(.callout.weight(.semibold)).textSelection(.enabled)
                        Spacer()
                        Text(activity.seconds.compactDuration).font(.callout.monospacedDigit())
                    }
                    Text("\(activity.startedAt.formatted(date: .omitted, time: .shortened)) – \(activity.endedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Text(activity.category).foregroundStyle(color)
                        if activity.isCurrent { Label("Current block", systemImage: "record.circle") }
                        if activity.isEstimated { Label("Estimated timing", systemImage: "clock.badge.questionmark") }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AnalyticsEmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }
}

struct DayPicker: View {
    @Binding var date: Date

    var body: some View {
        HStack(spacing: 12) {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .help("Previous day")
            DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .disabled(Calendar.current.isDateInToday(date))
                .help("Next day")
            Spacer(minLength: 0)
            Button("Today") { date = Date() }
                .disabled(Calendar.current.isDateInToday(date))
        }
        .buttonStyle(.bordered)
    }

    private func move(_ days: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: days, to: date) { date = min(next, Date()) }
    }
}

// Draw directly with SwiftUI so the donut also builds with the macOS 13 SDK.
private struct AllocationSector: Shape {
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.67
        let gap = end - start >= 1 ? 0 : min(2 / max(1, Double(innerRadius)), (end - start) * Double.pi / 2)
        let startAngle = Angle.radians(start * 2 * .pi - .pi / 2 + gap / 2)
        let endAngle = Angle.radians(end * 2 * .pi - .pi / 2 - gap / 2)
        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
