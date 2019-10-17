namespace Ai4Sf.TelemetryApi.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.EntityFrameworkCore;
    using System.Collections.Generic;
    using System.Linq;
    using System.Threading.Tasks;
    using Ai4Sf.Common.Models;
    using Ai4Sf.TelemetryApi.Models;

    [Route("api/[controller]")]
    [ApiController]
    public class TelemetryController : ControllerBase
    {
        private readonly TelemetryContext _context;

        public TelemetryController(TelemetryContext context)
        {
            _context = context;
        }

        // GET: api/Todo
        [HttpGet]
        public async Task<ActionResult<IEnumerable<TelemetryItem>>> Get()
        {
            return await _context.TelemetryItems.ToListAsync();
        }

        // GET: api/Todo/5
        [HttpGet("{id}")]
        public async Task<ActionResult<TelemetryItem>> Get(long id)
        {
            var todoItem = await _context.TelemetryItems.FindAsync(id);

            if (todoItem == null)
            {
                return NotFound();
            }

            return todoItem;
        }

        // POST: api/Todo
        [HttpPost]
        public async Task<ActionResult<TelemetryItem>> Post(TelemetryItem item)
        {
            _context.TelemetryItems.Add(item);
            await _context.SaveChangesAsync();

            return CreatedAtAction("Get", new { id = item.Id }, item);
        }
    }
}