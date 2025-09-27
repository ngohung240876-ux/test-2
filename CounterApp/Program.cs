// Console application that counts from start to end value

// Configuration - consider moving to appsettings.json for larger applications
const int DefaultStartValue = 1;
const int DefaultEndValue = 100; // Reduced from 1000 for better user experience
const int FirstArgumentIndex = 0;
const int SecondArgumentIndex = 1;

// Allow command line arguments to override defaults
int startValue = args.Length > FirstArgumentIndex && int.TryParse(args[FirstArgumentIndex], out int start) ? start : DefaultStartValue;
int endValue = args.Length > SecondArgumentIndex && int.TryParse(args[SecondArgumentIndex], out int end) ? end : DefaultEndValue;

// Validate input ranges
if (startValue > endValue)
{
    Console.WriteLine("Error: Start value cannot be greater than end value.");
    return;
}

Console.WriteLine($"Counting from {startValue} to {endValue}:");
Console.WriteLine();

// Direct console output is more appropriate for this simple use case
for (int i = startValue; i <= endValue; i++)
{
    Console.WriteLine($"{i} - I'm hieu");
}

Console.WriteLine();
Console.WriteLine($"Finished counting to {endValue}!");
