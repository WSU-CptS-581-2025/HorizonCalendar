import HorizonCalendar
import UIKit

final class HolidayCalendarViewController: BaseDemoViewController {

    // MARK: Lifecycle

    required init(monthsLayout: MonthsLayout) {
        super.init(monthsLayout: monthsLayout)
        selectedDate = calendar.date(from: DateComponents(year: 2020, month: 01, day: 19))!
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Holiday Calendar"
        setupHolidayPopup()

        calendarView.daySelectionHandler = { [weak self] day in
            guard let self = self else { return }

            self.selectedDate = self.calendar.date(from: day.components)
            self.calendarView.setContent(self.makeContent())

            if let selectedDate = self.selectedDate,
               let holidayName = self.holidays[selectedDate] {
                self.showHolidayPopup(with: holidayName)
            } else {
                self.hideHolidayPopup()
            }
        }
    }

    override func makeContent() -> CalendarViewContent {
        let startDate = calendar.date(from: DateComponents(year: 2023, month: 01, day: 01))!
        let endDate = calendar.date(from: DateComponents(year: 2023, month: 12, day: 31))!

        holidays = loadHolidays()

        return CalendarViewContent(
            calendar: calendar,
            visibleDateRange: startDate...endDate,
            monthsLayout: monthsLayout)
            .interMonthSpacing(24)
            .verticalDayMargin(8)
            .horizontalDayMargin(8)
            .dayItemProvider { [calendar] day in
                let date = calendar.date(from: day.components)
                var invariantViewProperties = DayView.InvariantViewProperties.baseInteractive

                if let holidayName = self.holidays[date ?? Date()] {
                    invariantViewProperties.backgroundShapeDrawingConfig.borderColor = .red
                    invariantViewProperties.backgroundShapeDrawingConfig.fillColor = .red.withAlphaComponent(0.15)

                    return DayView.calendarItemModel(
                        invariantViewProperties: invariantViewProperties,
                        content: .init(
                            dayText: "\(day.day)",
                            accessibilityLabel: holidayName,
                            accessibilityHint: "Holiday: \(holidayName)"))
                } else {
                    return DayView.calendarItemModel(
                        invariantViewProperties: invariantViewProperties,
                        content: .init(
                            dayText: "\(day.day)",
                            accessibilityLabel: date.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) },
                            accessibilityHint: nil))
                }
            }
    }

    // MARK: Private

    private var selectedDate: Date?
    private var holidays: [Date: String] = [:]

    private let holidayPopup: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.systemYellow
        label.textColor = UIColor.black
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.alpha = 0
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        return label
    }()

    private func setupHolidayPopup() {
        view.addSubview(holidayPopup)
        holidayPopup.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            holidayPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            holidayPopup.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            holidayPopup.widthAnchor.constraint(equalToConstant: 200),
            holidayPopup.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }

    private func showHolidayPopup(with text: String) {
        holidayPopup.text = "🎉 \(text)"
        UIView.animate(withDuration: 0.3) {
            self.holidayPopup.alpha = 1
        }
    }

    private func hideHolidayPopup() {
        UIView.animate(withDuration: 0.3) {
            self.holidayPopup.alpha = 0
        }
    }

    private func loadHolidays() -> [Date: String] {
        var holidays: [Date: String] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"

        holidays[formatter.date(from: "2023/01/01")!] = "New Year's Day"
        holidays[formatter.date(from: "2023/02/14")!] = "Valentine's Day"
        holidays[formatter.date(from: "2023/03/17")!] = "St. Patrick's Day"
        holidays[formatter.date(from: "2023/04/01")!] = "April Fool's Day"
        holidays[formatter.date(from: "2023/10/31")!] = "Halloween"
        holidays[formatter.date(from: "2023/12/25")!] = "Christmas Day"
        holidays[formatter.date(from: "2023/12/31")!] = "New Year's Eve"
        holidays[formatter.date(from: "2023/07/04")!] = "Independence Day"
        holidays[formatter.date(from: "2023/11/24")!] = "Thanksgiving Day"
        holidays[formatter.date(from: "2023/05/05")!] = "Cinco de Mayo"
        holidays[formatter.date(from: "2023/07/14")!] = "Bastille Day"
        holidays[formatter.date(from: "2023/10/03")!] = "German Unity Day"
        holidays[formatter.date(from: "2023/04/09")!] = "Easter Sunday"
        holidays[formatter.date(from: "2023/12/12")!] = "Hanukkah Starts"
        holidays[formatter.date(from: "2023/07/28")!] = "Eid al-Adha"
        holidays[formatter.date(from: "2023/11/12")!] = "Diwali"
        holidays[formatter.date(from: "2023/03/08")!] = "International Women's Day"
        holidays[formatter.date(from: "2023/05/01")!] = "International Workers' Day"
        holidays[formatter.date(from: "2023/06/19")!] = "Juneteenth"
        holidays[formatter.date(from: "2023/08/09")!] = "Indigenous Peoples Day"
        holidays[formatter.date(from: "2023/09/21")!] = "International Day of Peace"
        holidays[formatter.date(from: "2023/11/20")!] = "Universal Children's Day"

        return holidays
    }
}


