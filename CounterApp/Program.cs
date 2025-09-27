// Console application that counts from start to end value

// Configuration - consider moving to appsettings.json for larger applications
const int DefaultStartValue = 1;
const int DefaultEndValue = 100; // Reduced from 1000 for better user experience

// Allow command line arguments to override defaults
int startValue = args.Length > 0 && int.TryParse(args[0], out int start) ? start : DefaultStartValue;
int endValue = args.Length > 1 && int.TryParse(args[1], out int end) ? end : DefaultEndValue;

Console.WriteLine($"Counting from {startValue} to {endValue}:");
Console.WriteLine();

// Direct console output is more appropriate for this simple use case
for (int i = startValue; i <= endValue; i++)
{
    Console.WriteLine(i);
}

Console.WriteLine();
Console.WriteLine($"Finished counting to {endValue}!");
