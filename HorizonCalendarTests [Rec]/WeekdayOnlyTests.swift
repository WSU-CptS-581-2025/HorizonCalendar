import XCTest
@testable import HorizonCalendar

final class DisabledWeekdaysTests: XCTestCase {
    
    // MARK: - Properties
    
    private var calendar: Calendar!
    private var visibleDateRange: ClosedRange<Date>!
    private var size: CGSize!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        
        calendar = Calendar.current
        
        let startDate = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2023, month: 12, day: 31))!
        visibleDateRange = startDate...endDate
        
        size = CGSize(width: 320, height: 400)
    }
    
    // MARK: - Tests
    
    func testWeekdayVisibilityFiltering() {
        // Create content with only weekdays (Monday-Friday) visible
        let content = CalendarViewContent(
            calendar: calendar,
            visibleDateRange: visibleDateRange,
            monthsLayout: .vertical(options: .init()),
            visibleWeekdays: Set(2...6)) // Monday = 2, Friday = 6
        
        // Confirm the visibleWeekdays property is set correctly
        XCTAssertEqual(content.visibleWeekdays, Set(2...6), "visibleWeekdays should be set to weekdays only")
        
        // Create sample dates for both weekdays and weekends
        let mondayDate = calendar.date(from: DateComponents(year: 2023, month: 1, day: 2))! // Monday
        let wednesdayDate = calendar.date(from: DateComponents(year: 2023, month: 1, day: 4))! // Wednesday
        let fridayDate = calendar.date(from: DateComponents(year: 2023, month: 1, day: 6))! // Friday
        let saturdayDate = calendar.date(from: DateComponents(year: 2023, month: 1, day: 7))! // Saturday
        let sundayDate = calendar.date(from: DateComponents(year: 2023, month: 1, day: 8))! // Sunday
        
        // Create Day objects for testing
        let mondayDay = Day(month: createMonthFrom(date: mondayDate), day: calendar.component(.day, from: mondayDate))
        let wednesdayDay = Day(month: createMonthFrom(date: wednesdayDate), day: calendar.component(.day, from: wednesdayDate))
        let fridayDay = Day(month: createMonthFrom(date: fridayDate), day: calendar.component(.day, from: fridayDate))
        let saturdayDay = Day(month: createMonthFrom(date: saturdayDate), day: calendar.component(.day, from: saturdayDate))
        let sundayDay = Day(month: createMonthFrom(date: sundayDate), day: calendar.component(.day, from: sundayDate))
        
        // Test whether each day's weekday is visible according to content's visibleWeekdays
        XCTAssertTrue(isWeekdayVisible(mondayDay, in: content), "Monday should be visible")
        XCTAssertTrue(isWeekdayVisible(wednesdayDay, in: content), "Wednesday should be visible")
        XCTAssertTrue(isWeekdayVisible(fridayDay, in: content), "Friday should be visible")
        
        // Weekend days should be filtered out
        XCTAssertFalse(isWeekdayVisible(saturdayDay, in: content), "Saturday should not be visible")
        XCTAssertFalse(isWeekdayVisible(sundayDay, in: content), "Sunday should not be visible")
    }
    
    func testDayRangeWithDisabledDays() {
        // Create a custom availability provider that disables weekends
        class WeekendAvailabilityProvider: DayAvailabilityProvider {
            let calendar = Calendar.current
            
            func isEnabled(_ day: DayComponents) -> Bool {
                guard let date = calendar.date(from: day.components) else { return true }
                return isEnabled(date)
            }
            
            func isEnabled(_ date: Date) -> Bool {
                let weekday = calendar.component(.weekday, from: date)
                return !(weekday == 1 || weekday == 7) // Disable Sundays (1) and Saturdays (7)
            }
        }
        
        // Set the availability provider
        Day.availabilityProvider = WeekendAvailabilityProvider()
        defer { Day.availabilityProvider = nil } // Clean up
        
        // Create a day range that spans a week including weekends
        let startDayComponents = DayComponents(month: MonthComponents(era: 1, year: 2023, month: 1, isInGregorianCalendar: true), day: 6) // Friday
        let endDayComponents = DayComponents(month: MonthComponents(era: 1, year: 2023, month: 1, isInGregorianCalendar: true), day: 10) // Tuesday
        
        let startDay = Day(month: startDayComponents.month, day: startDayComponents.day)
        let endDay = Day(month: endDayComponents.month, day: endDayComponents.day)
        
        // Create a day range
        let dayRange = startDay...endDay
        
        // Verify some days in the range are disabled
        var currentDate = calendar.date(from: startDay.components)!
        let endDate = calendar.date(from: endDay.components)!
        
        var hasDisabledDays = false
        while currentDate <= endDate {
            let currentMonth = createMonthFrom(date: currentDate)
            let currentDay = Day(month: currentMonth, day: calendar.component(.day, from: currentDate))
            if !currentDay.isEnabled {
                hasDisabledDays = true
                break
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        XCTAssertTrue(hasDisabledDays, "Day range should contain disabled days (weekends)")
    }
    
    func testRangeSelectionWithDisabledDays() {
        // Create a custom availability provider that disables weekends
        class WeekendAvailabilityProvider: DayAvailabilityProvider {
            let calendar = Calendar.current
            
            func isEnabled(_ day: DayComponents) -> Bool {
                guard let date = calendar.date(from: day.components) else { return true }
                return isEnabled(date)
            }
            
            func isEnabled(_ date: Date) -> Bool {
                let weekday = calendar.component(.weekday, from: date)
                return !(weekday == 1 || weekday == 7) // Disable Sundays (1) and Saturdays (7)
            }
        }
        
        // Set the availability provider
        Day.availabilityProvider = WeekendAvailabilityProvider()
        defer { Day.availabilityProvider = nil } // Clean up
        
        // Create start and end days that span a weekend
        let friday = Day(month: MonthComponents(era: 1, year: 2023, month: 1, isInGregorianCalendar: true), day: 6)
        let monday = Day(month: MonthComponents(era: 1, year: 2023, month: 1, isInGregorianCalendar: true), day: 9)
        
        // Check if these days are enabled
        XCTAssertTrue(friday.isEnabled, "Friday should be enabled")
        XCTAssertTrue(monday.isEnabled, "Monday should be enabled")
        
        // Use DayRangeSelectionHelper to get invalid dates in a range
        let dayRange: DayComponentsRange = friday...monday
        let invalidDates = DayRangeSelectionHelper.getInvalidDateSet(friday, dayRange, calendar)
        
        // Verify that we detected invalid dates (weekends) in the range
        XCTAssertFalse(invalidDates.isEmpty, "Selection should contain invalid weekend dates")
        XCTAssertEqual(invalidDates.count, 2, "There should be exactly 2 invalid dates (Saturday and Sunday)")
        
        // Verify the invalid dates are actually weekend days
        for date in invalidDates {
            let weekday = calendar.component(.weekday, from: date)
            XCTAssertTrue(weekday == 1 || weekday == 7, "Invalid date should be a weekend day")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMonthFrom(date: Date) -> MonthComponents {
        let components = calendar.dateComponents([.era, .year, .month], from: date)
        return MonthComponents(
            era: components.era ?? 1,
            year: components.year ?? 2023,
            month: components.month ?? 1,
            isInGregorianCalendar: calendar.identifier == .gregorian)
    }
    
    private func isWeekdayVisible(_ day: Day, in content: CalendarViewContent) -> Bool {
        guard let date = calendar.date(from: day.components) else { return false }
        let weekday = calendar.component(.weekday, from: date)
        return content.visibleWeekdays.contains(weekday)
    }
}
