
namespace Ai4Sf.Frontend.Controllers
{
    using System;
    using Microsoft.AspNetCore.Mvc;

    [Route("")]
    [Route("Home")]
    [Route("Home/Index")]
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            return Ok($"Running on: {Environment.MachineName}");
        }
    }
}
