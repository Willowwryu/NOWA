//
//  ContentView.swift
//  nowA
//
//  Created by 유재훈 on 1/19/26.
//

import CoreLocation
import EventKit
import SwiftUI
#if canImport(WeatherKit)
import WeatherKit
#endif

struct ContentView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            DateCardView(
                                day: viewModel.dayText,
                                month: viewModel.monthText,
                                weekday: viewModel.weekdayText
                            )
                            WeatherCardView(
                                temperature: viewModel.temperatureText,
                                condition: viewModel.conditionText,
                                highLow: viewModel.highLowText
                            )
                        }

                        TimeCardView(time: viewModel.timeText)

                        Spacer(minLength: 0)
                    }
                    .frame(width: proxy.size.width * 0.52, alignment: .leading)

                    EventListView(events: viewModel.events)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(24)
            }
        }
        .onAppear {
            viewModel.start()
        }
        .preferredColorScheme(.dark)
    }
}

struct DateCardView: View {
    let day: String
    let month: String
    let weekday: String

    var body: some View {
        HStack(spacing: 12) {
            Text(day)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(month)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text(weekday)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(white: 0.2))
    }
}

struct WeatherCardView: View {
    let temperature: String
    let condition: String
    let highLow: String

    var body: some View {
        HStack(spacing: 12) {
            Text(temperature)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(condition)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text(highLow)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(white: 0.2))
    }
}

struct TimeCardView: View {
    let time: String

    var body: some View {
        Text(time)
            .font(.system(size: 120, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(white: 0.18))
            )
    }
}

struct EventListView: View {
    let events: [CalendarEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(events) { event in
                EventRowView(event: event)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }
}

struct EventRowView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.red)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(event.timeRange)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.2))
        )
    }
}

struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let timeRange: String
}

@MainActor
final class DashboardViewModel: NSObject, ObservableObject {
    @Published var timeText: String = ""
    @Published var dayText: String = ""
    @Published var monthText: String = ""
    @Published var weekdayText: String = ""
    @Published var temperatureText: String = "--°"
    @Published var conditionText: String = "날씨 확인 중"
    @Published var highLowText: String = "-- / --"
    @Published var events: [CalendarEvent] = []

    private let eventStore = EKEventStore()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d"
        return formatter
    }()

    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private var timer: Timer?
    private let locationManager = CLLocationManager()

    func start() {
        updateDateTime()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateDateTime()
        }
        requestCalendarAccess()
        requestLocationAccess()
    }

    private func updateDateTime() {
        let now = Date()
        timeText = dateFormatter.string(from: now)
        dayText = dayFormatter.string(from: now)
        monthText = monthFormatter.string(from: now)
        weekdayText = weekdayFormatter.string(from: now)
    }

    private func requestCalendarAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            guard granted else { return }
            Task { @MainActor in
                self?.loadUpcomingEvents()
            }
        }
    }

    private func loadUpcomingEvents() {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let upcoming = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(4)
            .map { event in
                CalendarEvent(title: event.title ?? "일정", timeRange: formattedTimeRange(for: event))
            }

        events = upcoming.isEmpty ? [
            CalendarEvent(title: "오늘의 일정이 없습니다", timeRange: "")
        ] : Array(upcoming)
    }

    private func formattedTimeRange(for event: EKEvent) -> String {
        let start = dateFormatter.string(from: event.startDate)
        let end = dateFormatter.string(from: event.endDate)
        return "\(start) ~ \(end)"
    }

    private func requestLocationAccess() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
}

extension DashboardViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            await updateWeather(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            conditionText = "날씨를 가져올 수 없음"
        }
    }
}

extension DashboardViewModel {
    @MainActor
    private func updateWeather(for location: CLLocation) async {
        #if canImport(WeatherKit)
        do {
            let weather = try await WeatherService().weather(for: location)
            let current = weather.currentWeather
            temperatureText = String(format: "%.0f°", current.temperature.value)
            conditionText = current.condition.description
            let daily = weather.dailyForecast.forecast.first
            if let daily {
                highLowText = String(
                    format: "%.0f° / %.0f°",
                    daily.highTemperature.value,
                    daily.lowTemperature.value
                )
            }
        } catch {
            conditionText = "날씨를 가져올 수 없음"
        }
        #else
        conditionText = "날씨 기능 사용 불가"
        #endif
    }
}

#Preview {
    ContentView()
}
