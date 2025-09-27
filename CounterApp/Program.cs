// Console application that counts from start to end value
using System.Text;

const int START_VALUE = 1;
const int END_VALUE = 1000;

Console.WriteLine($"Counting from {START_VALUE} to {END_VALUE}:");
Console.WriteLine();

// Use StringBuilder for better performance when dealing with large ranges
var output = new StringBuilder();
for (int i = START_VALUE; i <= END_VALUE; i++)
{
    output.AppendLine(i.ToString());
}
Console.Write(output.ToString());

Console.WriteLine();
Console.WriteLine($"Finished counting to {END_VALUE}!");
